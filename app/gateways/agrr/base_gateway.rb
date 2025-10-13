# frozen_string_literal: true

require 'open3'
require 'tempfile'

module Agrr
  class BaseGateway
    class ExecutionError < StandardError; end
    class ParseError < StandardError; end
    
    private
    
    def execute_command(*args, parse_json: true)
      Rails.logger.info "🔧 [AGRR] Executing: #{args.join(' ')}"
      
      stdout, stderr, status = Open3.capture3(*args)
      
      # 実行結果を常に詳細ログ出力
      Rails.logger.info "📊 [AGRR] Exit code: #{status.exitstatus}"
      
      if stdout.present?
        Rails.logger.info "📝 [AGRR] stdout (#{stdout.bytesize} bytes): #{stdout.first(500)}#{stdout.bytesize > 500 ? '...' : ''}"
      else
        Rails.logger.info "📝 [AGRR] stdout: (empty)"
      end
      
      if stderr.present?
        Rails.logger.warn "⚠️ [AGRR] stderr (#{stderr.bytesize} bytes): #{stderr}"
      else
        Rails.logger.info "📝 [AGRR] stderr: (empty)"
      end
      
      # Exit code 0でもstdoutがエラーメッセージの場合はエラーとして扱う
      if stdout.present? && stdout.strip.start_with?('Error', '❌')
        Rails.logger.error "❌ [AGRR] Command returned error message in stdout (exit code: #{status.exitstatus})"
        error_message = stdout.lines.first&.strip || stdout
        raise ExecutionError, "Command returned error: #{error_message}"
      end
      
      unless status.success?
        Rails.logger.error "❌ [AGRR] Command failed (exit code: #{status.exitstatus})"
        raise ExecutionError, "Command failed (exit #{status.exitstatus}): #{stderr.presence || stdout.presence || 'Unknown error'}"
      end
      
      return stdout unless parse_json
      
      JSON.parse(stdout)
    rescue JSON::ParserError => e
      Rails.logger.error "❌ [AGRR] Failed to parse JSON: #{e.message}"
      Rails.logger.error "stdout (first 500 chars): #{stdout&.first(500)}"
      # stdoutにエラーメッセージが含まれている場合は、より分かりやすいエラーを投げる
      if stdout&.include?('Error')
        error_line = stdout.lines.first&.strip || stdout
        raise ParseError, "Command returned error instead of JSON: #{error_line}"
      end
      raise ParseError, "Failed to parse JSON: #{e.message}"
    end
    
    def agrr_path
      @agrr_path ||= Rails.root.join('lib/core/agrr').to_s
    end
    
    def write_temp_file(data, prefix: 'agrr_data')
      file = Tempfile.new([prefix, '.json'])
      file.write(data.to_json)
      file.flush
      file
    end
  end
end

