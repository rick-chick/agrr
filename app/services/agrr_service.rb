# frozen_string_literal: true

require 'open3'
require 'tempfile'

class AgrrService
  class AgrrError < StandardError; end
  class DaemonNotRunningError < AgrrError; end
  class CommandExecutionError < AgrrError; end
  # 再帰呼び出しで発生した例外をラップする例外クラス
  # この例外は既にリトライ済みであることを示す
  class RetryFailedError < AgrrError
    attr_reader :original_error

    def initialize(original_error)
      @original_error = original_error
      super("Retry failed: #{original_error.message}")
      set_backtrace(original_error.backtrace)
    end
  end

  def initialize
    @client_path = Rails.root.join('bin', 'agrr_client')
    @socket_path = '/tmp/agrr.sock'
  end

  # Check if daemon is running
  def daemon_running?
    File.exist?(@socket_path) && File.socket?(@socket_path)
  end

  # Get weather data
  def weather(location:, start_date: nil, end_date: nil, days: nil, data_source: 'noaa', json: true)
    ensure_daemon_running!

    # 日本国内の場合はデフォルトのnoaaからjmaまたはopenmeteoに切り替える
    if data_source == 'noaa' && location_in_japan?(location)
      Rails.logger.info "🇯🇵 [AgrrService] Location in Japan detected, switching data source from noaa to jma"
      data_source = 'jma'
    end

    output_file = nil
    output_path = nil

    output_file = Tempfile.new(['weather_output', '.json'])
    output_path = output_file.path
    output_file.close

    args = ['weather', '--location', location]
    args += ['--start-date', start_date] if start_date
    args += ['--end-date', end_date] if end_date
    args += ['--days', days.to_s] if days
    args += ['--data-source', data_source] if data_source
    args += ['--output', output_path]
    args << '--json' if json

    execute_command(args)

    unless output_path && File.exist?(output_path)
      raise CommandExecutionError, 'Weather command did not produce an output file'
    end

    output_content = File.read(output_path)
    if output_content.blank?
      Rails.logger.error "❌ [AgrrService] Weather command produced an empty output file for location: #{location}, source: #{data_source}"
      raise CommandExecutionError, "Weather data not available for this location from #{data_source}. Please try a different data source."
    end

    output_content
  ensure
    if output_file
      begin
        output_file.close!
      rescue Errno::ENOENT, IOError
        # already removed or closed
      end
    end
  end

  # Get weather forecast
  def forecast(location:, json: true)
    ensure_daemon_running!

    args = ['forecast', '--location', location]
    args << '--json' if json

    execute_command(args)
  end

  # Get crop profile
  def crop(query:, json: true)
    ensure_daemon_running!

    args = ['crop', '--query', query]
    args << '--json' if json

    execute_command(args)
  end

  # Calculate crop progress
  def progress(crop_file:, start_date:, weather_file:, json: true)
    ensure_daemon_running!

    args = ['progress', '--crop-file', crop_file, '--start-date', start_date, '--weather-file', weather_file]
    args += ['--format', 'json'] if json

    execute_command(args)
  end

  # Optimize period
  def optimize_period(crop_file:, evaluation_start:, evaluation_end:, weather_file:, field_file:, interaction_rules_file: nil)
    ensure_daemon_running!

    args = ['optimize', 'period', '--crop-file', crop_file, '--evaluation-start', evaluation_start, 
            '--evaluation-end', evaluation_end, '--weather-file', weather_file, '--field-file', field_file]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Optimize allocation
  def optimize_allocate(fields_file:, crops_file:, planning_start:, planning_end:, weather_file:, format: 'json', interaction_rules_file: nil)
    ensure_daemon_running!

    args = ['optimize', 'allocate', '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, 
            '--weather-file', weather_file, '--format', format]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Generate candidate suggestions
  def optimize_candidates(allocation:, fields_file:, crops_file:, target_crop:, planning_start:, planning_end:, weather_file:, output:, format: 'json', interaction_rules_file: nil)
    ensure_daemon_running!

    args = ['optimize', 'candidates', '--allocation', allocation, '--fields-file', fields_file,
            '--crops-file', crops_file, '--target-crop', target_crop,
            '--planning-start', planning_start, '--planning-end', planning_end,
            '--weather-file', weather_file, '--output', output, '--format', format]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Adjust allocation
  def optimize_adjust(current_allocation:, moves:, weather_file:, fields_file:, crops_file:, planning_start:, planning_end:, format: 'json', interaction_rules_file: nil)
    ensure_daemon_running!

    args = ['optimize', 'adjust', '--current-allocation', current_allocation, '--moves', moves,
            '--weather-file', weather_file, '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, '--format', format]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Predict weather
  def predict(input:, output:, days:, model: 'lightgbm', metrics: nil)
    ensure_daemon_running!

    args = ['predict', '--input', input, '--output', output, '--days', days.to_s, '--model', model]
    args += ['--metrics', metrics] if metrics && !metrics.to_s.empty?

    execute_command(args)
  end

  # Generate task schedule
  def schedule(crop_name:, variety:, stage_requirements:, agricultural_tasks:, output: nil, json: true)
    ensure_daemon_running!

    args = ['schedule', '--crop-name', crop_name, '--variety', variety,
            '--stage-requirements', stage_requirements, '--agricultural-tasks', agricultural_tasks]
    args += ['--output', output] if output
    args << '--json' if json

    execute_command(args)
  end

  # Plan fertilizer applications
  def fertilize_plan(crop_file:, use_harvest_start: false, max_applications: 2, json: true)
    ensure_daemon_running!

    args = ['fertilize', 'plan', '--crop-file', crop_file]
    args << '--use-harvest-start' if use_harvest_start
    # デフォルトで最大施用回数を2に制限
    args += ['--max-applications', max_applications.to_s] if max_applications
    args << '--json' if json

    execute_command(args)
  end

  # Get pest profile by pest name
  def pest_to_crop(pest:, crops:, language: 'ja')
    ensure_daemon_running!

    args = ['pest-to-crop', '--pest', pest, '--crops', crops, '--language', language]

    execute_command(args)
  end

  private

  def execute_command(args, retried: false)
    Rails.logger.info "Executing AGRR command: #{args.join(' ')}"
    
    stdout, stderr, status = Open3.capture3(@client_path.to_s, *args)
    
    Rails.logger.info "🔍 [AgrrService] Exit code: #{status.exitstatus}"
    Rails.logger.info "🔍 [AgrrService] stdout length: #{stdout&.length || 0}, content: #{stdout&.first(100)}..."
    Rails.logger.info "🔍 [AgrrService] stdout last 100: #{stdout&.last(100) if stdout}" if stdout&.length.to_i > 200
    Rails.logger.info "🔍 [AgrrService] stderr length: #{stderr&.length || 0}, content: #{stderr&.first(100)}..."
    
    # Check if stdout contains valid JSON (even if exit code is non-zero)
    has_valid_json = stdout&.strip&.start_with?('{') || stdout&.strip&.start_with?('[')
    
    # Extract only the JSON part if there's extra text after the JSON
    if has_valid_json
      # Find the last } or ] to extract only the JSON
      last_brace = stdout.rindex('}')
      last_bracket = stdout.rindex(']')
      last_pos = [last_brace, last_bracket].compact.max
      if last_pos
        clean_output = stdout[0..last_pos]
        Rails.logger.info "🔍 [AgrrService] Extracted JSON (removed #{stdout.length - clean_output.length} chars after JSON)"
      else
        clean_output = stdout
      end
    else
      clean_output = stdout
    end
    
    if status.success?
      # 成功ステータスだがstdoutが空でstderrに明らかなエラーが含まれているケースをエラーとして扱う
      if (clean_output.nil? || clean_output.strip.empty?) && stderr.present?
        if stderr.include?('Traceback (most recent call last):') || stderr.downcase.include?('error')
          Rails.logger.error "❌ [AgrrService] Command reported success but stderr contains error output"
          Rails.logger.error "❌ [AgrrService] stderr: #{stderr}"
          raise CommandExecutionError, stderr
        end
      end

      clean_output || stdout
    elsif has_valid_json && stderr.blank?
      # Exit code is non-zero but we have valid JSON and no stderr
      # This is likely a warning in the daemon but the result is still valid
      Rails.logger.warn "⚠️ [AgrrService] Command returned exit code #{status.exitstatus} but has valid JSON output (likely warning)"
      clean_output || stdout
    else
      error_message = stderr.presence || "Command failed with exit code #{status.exitstatus}"

      # Daemon未起動の可能性がある場合は、自動起動して1回だけリトライする
      if !retried && should_retry_with_daemon_start?(error_message, stderr)
        Rails.logger.info "[AgrrService] Command failed, attempting to start daemon and retry..."

        if start_daemon_if_not_running
          # リトライを実行
          # 再帰呼び出しで例外が発生した場合、RetryFailedErrorでラップして
          # 元の呼び出しで再度リトライされないようにする
          begin
            return execute_command(args, retried: true)
          rescue RetryFailedError => e
            # 再帰呼び出しでもRetryFailedErrorが発生した場合は、そのまま再発生
            raise e
          rescue => retry_error
            # 再帰呼び出しで発生した例外をラップして再発生
            # これにより、元の呼び出しのrescueブロックで
            # 既にリトライ済みであることが識別できる
            raise RetryFailedError, retry_error
          end
        else
          Rails.logger.warn "[AgrrService] Failed to start daemon, raising DaemonNotRunningError"
          raise DaemonNotRunningError, 'AGRR daemon is not running'
        end
      end

      Rails.logger.error "AGRR command failed: #{error_message}"
      raise CommandExecutionError, error_message
    end
  rescue RetryFailedError => e
    # 再帰呼び出しで発生した例外は既にリトライ済みなので、
    # 元の例外を再発生させてそれ以上リトライしない
    raise e.original_error
  rescue => e
    # ソケット接続エラーなどの予期しないエラーもリトライ対象とする
    # ただし、既にリトライ済み（retried: true）の場合は再リトライしない
    if !retried && (e.is_a?(Errno::ECONNREFUSED) || e.message.to_s.include?('socket') || e.message.to_s.include?('Connection refused'))
      Rails.logger.info "[AgrrService] Connection error detected, attempting to start daemon and retry..."

      if start_daemon_if_not_running
        # リトライを実行
        # 再帰呼び出しで例外が発生した場合、RetryFailedErrorでラップして
        # 元の呼び出しで再度リトライされないようにする
        begin
          return execute_command(args, retried: true)
        rescue RetryFailedError => e
          # 再帰呼び出しでもRetryFailedErrorが発生した場合は、そのまま再発生
          raise e
        rescue => retry_error
          # 再帰呼び出しで発生した例外をラップして再発生
          # これにより、元の呼び出しのrescueブロックで
          # 既にリトライ済みであることが識別できる
          raise RetryFailedError, retry_error
        end
      else
        Rails.logger.warn "[AgrrService] Failed to start daemon after connection error, raising DaemonNotRunningError"
        raise DaemonNotRunningError, 'AGRR daemon is not running'
      end
    end

    raise
  end

  def ensure_daemon_running!
    return true if daemon_running?

    if start_daemon_if_not_running
      return true
    end

    raise DaemonNotRunningError, 'AGRR daemon is not running'
  end

  def start_daemon_if_not_running
    return true if daemon_running?

    agrr_bin = find_agrr_binary
    unless agrr_bin
      Rails.logger.warn "[AgrrService] AGRR binary not found, skipping daemon auto-start"
      return false
    end

    Rails.logger.info "[AgrrService] AGRR daemon is not running, attempting to start..."

    stdout, stderr, status = Open3.capture3(agrr_bin, 'daemon', 'start')

    unless status.success?
      Rails.logger.error "[AgrrService] Failed to start AGRR daemon: #{stderr}"
      return false
    end

    max_wait_time = 5.0
    poll_interval = 0.5
    elapsed = 0.0

    while elapsed < max_wait_time
      sleep(poll_interval)
      elapsed += poll_interval

      if daemon_running?
        Rails.logger.info "[AgrrService] AGRR daemon started successfully (waited #{elapsed.round(1)}s)"
        return true
      end
    end

    # タイムアウト後は明示的にfalseを返す
    # フォールバックチェック（daemon_running?）を使わず、エラーとして扱う
    Rails.logger.error "[AgrrService] AGRR daemon did not start within #{max_wait_time}s timeout"
    false
  end

  def find_agrr_binary
    agrr_bin = ENV['AGRR_BIN_PATH']
    return agrr_bin if agrr_bin.present? && File.executable?(agrr_bin)

    default_path = '/usr/local/bin/agrr'
    return default_path if File.executable?(default_path)

    # 開発環境: プロジェクト内 lib/core/agrr（Docker と同じパス）
    project_path = Rails.root.join('lib/core/agrr').to_s
    return project_path if File.executable?(project_path)

    nil
  end

  def should_retry_with_daemon_start?(error_message, stderr)
    combined_error = "#{error_message} #{stderr}".downcase

    combined_error.include?('connection refused') ||
      combined_error.include?('no such file') ||
      combined_error.include?('socket') ||
      combined_error.include?('daemon') ||
      !daemon_running?
  end

  def location_in_japan?(location)
    return false unless location.present?

    # location format: "lat,lon"
    lat, lon = location.split(',').map(&:to_f)
    return false if lat == 0.0 && lon == 0.0

    # 緯度: 20-46, 経度: 122-154
    lat.between?(20.0, 46.0) && lon.between?(122.0, 154.0)
  end

  # 気象データのフォーマットを正規化（古いネスト形式を解消）
  def self.normalize_weather_data(data)
    return nil if data.blank?

    if data['data'].is_a?(Hash) && data['data']['data'].is_a?(Array)
      Rails.logger.warn "⚠️ [AgrrService] Old nested weather format detected, extracting inner data"
      data['data']
    else
      data
    end
  end
end
