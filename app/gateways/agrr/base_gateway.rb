# frozen_string_literal: true

require "open3"
require "tempfile"
require "timeout"

module Agrr
  class BaseGateway
    class ExecutionError < StandardError; end
    class ParseError < StandardError; end
    class NoAllocationCandidatesError < StandardError; end

    private

    def execute_command(*args, parse_json: true, timeout: 600)
      Rails.logger.info "🔧 [AGRR] Executing: #{args.join(' ')}"
      Rails.logger.info "⏱️ [AGRR] Timeout: #{timeout}s"

      stdout, stderr, status = Timeout.timeout(timeout) do
        Open3.capture3(*args)
      end

      # 実行結果を常に詳細ログ出力
      Rails.logger.info "📊 [AGRR] Exit code: #{status.exitstatus}"

      if stdout.present?
        preview = stdout[0...100]
        Rails.logger.info "📝 [AGRR] stdout (#{stdout.bytesize} bytes): #{preview}#{stdout.bytesize > 100 ? '...' : ''}"
      else
        Rails.logger.info "📝 [AGRR] stdout: (empty)"
      end

      if stderr.present?
        preview = stderr[0...100]
        Rails.logger.warn "⚠️ [AGRR] stderr (#{stderr.bytesize} bytes): #{preview}#{stderr.bytesize > 100 ? '...' : ''}"
      else
        Rails.logger.info "📝 [AGRR] stderr: (empty)"
      end

      # Exit code 0でもstdoutがエラーメッセージの場合はエラーとして扱う
      if stdout.present? && stdout.strip.start_with?("Error", "❌")
        Rails.logger.error "❌ [AGRR] Command returned error message in stdout (exit code: #{status.exitstatus})"
        # 完全なエラーメッセージを取得（最初の行だけでなく全体）
        error_message = stdout.strip

        # 特定のエラーメッセージに対して専用の例外を投げる
        if error_message.include?("No valid allocation candidates could be generated")
          raise NoAllocationCandidatesError, error_message
        end

        # 重複エラーの場合は、より詳細なメッセージを表示
        if error_message.include?("overlap") && error_message.include?("fallow period")
          raise ExecutionError, "#{error_message}"
        end

        raise ExecutionError, "#{error_message}"
      end

      unless status.success?
        Rails.logger.error "❌ [AGRR] Command failed (exit code: #{status.exitstatus})"
        error_output = stderr.presence || stdout.presence || "Unknown error"

        # 特定のエラーメッセージに対して専用の例外を投げる
        if error_output.include?("No valid allocation candidates could be generated")
          raise NoAllocationCandidatesError, error_output
        end

        raise ExecutionError, "Command failed (exit #{status.exitstatus}): #{error_output}"
      end

      return stdout unless parse_json

      # AGRR CLIが警告メッセージをstdoutに出力する場合があるので、JSONの部分だけを抽出
      json_content = extract_json_from_output(stdout)
      JSON.parse(json_content)
    rescue Timeout::Error => e
      Rails.logger.error "❌ [AGRR] Command timed out after #{timeout}s"
      Rails.logger.error "Command: #{args.join(' ')}"
      raise ExecutionError, "Command timed out after #{timeout} seconds. The operation may require more time or optimization."
    rescue JSON::ParserError => e
      Rails.logger.error "❌ [AGRR] Failed to parse JSON: #{e.message}"
      Rails.logger.error "stdout (first 500 chars): #{stdout&.first(500)}"
      # stdoutにエラーメッセージが含まれている場合は、より分かりやすいエラーを投げる
      if stdout&.include?("Error")
        error_line = stdout.lines.first&.strip || stdout
        raise ParseError, "Command returned error instead of JSON: #{error_line}"
      end
      raise ParseError, "Failed to parse JSON: #{e.message}"
    end

    # stdoutからJSONの部分だけを抽出する
    # AGRR CLIが警告メッセージをstdoutに出力する場合があるため、最初の{から最後の}までを抽出
    def extract_json_from_output(output)
      # 最初の { を見つける
      start_index = output.index("{")
      return output unless start_index

      # 最初の { から最後まで取得
      json_part = output[start_index..-1]

      # 最後の } を見つける
      end_index = json_part.rindex("}")
      return json_part unless end_index

      # { から } までを抽出
      json_part[0..end_index]
    end

    def write_temp_file(data, prefix: "agrr_data")
      file = Tempfile.new([ prefix, ".json" ])
      file.write(data.to_json)
      file.flush
      file
    end
  end
end
