# frozen_string_literal: true

require 'open3'

class AgrrService
  class AgrrError < StandardError; end
  class DaemonNotRunningError < AgrrError; end
  class CommandExecutionError < AgrrError; end

  def initialize
    @client_path = Rails.root.join('bin', 'agrr_client')
    @socket_path = '/tmp/agrr.sock'
  end

  # Check if daemon is running
  def daemon_running?
    File.exist?(@socket_path) && File.socket?(@socket_path)
  end

  # Get weather data
  def weather(location:, start_date: nil, end_date: nil, days: nil, data_source: 'openmeteo', json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['weather', '--location', location]
    args += ['--start-date', start_date] if start_date
    args += ['--end-date', end_date] if end_date
    args += ['--days', days.to_s] if days
    args += ['--data-source', data_source] if data_source
    args << '--json' if json

    execute_command(args)
  end

  # Get weather forecast
  def forecast(location:, json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['forecast', '--location', location]
    args << '--json' if json

    execute_command(args)
  end

  # Get crop profile
  def crop(query:, json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['crop', '--query', query]
    args << '--json' if json

    execute_command(args)
  end

  # Calculate crop progress
  def progress(crop_file:, start_date:, weather_file:, json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['progress', '--crop-file', crop_file, '--start-date', start_date, '--weather-file', weather_file]
    args += ['--format', 'json'] if json

    execute_command(args)
  end

  # Optimize period
  def optimize_period(crop_file:, evaluation_start:, evaluation_end:, weather_file:, field_file:, interaction_rules_file: nil)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['optimize', 'period', '--crop-file', crop_file, '--evaluation-start', evaluation_start, 
            '--evaluation-end', evaluation_end, '--weather-file', weather_file, '--field-file', field_file]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Optimize allocation
  def optimize_allocate(fields_file:, crops_file:, planning_start:, planning_end:, weather_file:, format: 'json')
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['optimize', 'allocate', '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, 
            '--weather-file', weather_file, '--format', format]

    execute_command(args)
  end

  # Adjust allocation
  def optimize_adjust(current_allocation:, moves:, weather_file:, fields_file:, crops_file:, planning_start:, planning_end:, format: 'json')
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['optimize', 'adjust', '--current-allocation', current_allocation, '--moves', moves,
            '--weather-file', weather_file, '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, '--format', format]

    execute_command(args)
  end

  # Predict weather
  def predict(input:, output:, days:, model: 'lightgbm', metrics: nil)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['predict', '--input', input, '--output', output, '--days', days.to_s, '--model', model]
    args += ['--metrics', metrics] if metrics && !metrics.to_s.empty?

    execute_command(args)
  end

  private

  def execute_command(args)
    Rails.logger.info "Executing AGRR command: #{args.join(' ')}"
    
    stdout, stderr, status = Open3.capture3(@client_path.to_s, *args)
    
    Rails.logger.info "🔍 [AgrrService] Exit code: #{status.exitstatus}"
    Rails.logger.info "🔍 [AgrrService] stdout length: #{stdout&.length || 0}, content: #{stdout&.first(100)}..."
    Rails.logger.info "🔍 [AgrrService] stderr length: #{stderr&.length || 0}, content: #{stderr&.first(100)}..."
    
    if status.success?
      stdout
    else
      error_message = stderr.presence || "Command failed with exit code #{status.exitstatus}"
      Rails.logger.error "AGRR command failed: #{error_message}"
      raise CommandExecutionError, error_message
    end
  end
end
