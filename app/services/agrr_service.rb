# frozen_string_literal: true

require 'open3'
require 'tempfile'

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
  def weather(location:, start_date: nil, end_date: nil, days: nil, data_source: 'noaa', json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

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
      raise CommandExecutionError, 'Weather command produced an empty output file'
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
  def optimize_allocate(fields_file:, crops_file:, planning_start:, planning_end:, weather_file:, format: 'json', interaction_rules_file: nil)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['optimize', 'allocate', '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, 
            '--weather-file', weather_file, '--format', format]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Adjust allocation
  def optimize_adjust(current_allocation:, moves:, weather_file:, fields_file:, crops_file:, planning_start:, planning_end:, format: 'json', interaction_rules_file: nil)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['optimize', 'adjust', '--current-allocation', current_allocation, '--moves', moves,
            '--weather-file', weather_file, '--fields-file', fields_file, '--crops-file', crops_file,
            '--planning-start', planning_start, '--planning-end', planning_end, '--format', format]
    args += ['--interaction-rules-file', interaction_rules_file] if interaction_rules_file

    execute_command(args)
  end

  # Predict weather
  def predict(input:, output:, days:, model: 'lightgbm', metrics: nil)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['predict', '--input', input, '--output', output, '--days', days.to_s, '--model', model]
    args += ['--metrics', metrics] if metrics && !metrics.to_s.empty?

    execute_command(args)
  end

  # Generate task schedule
  def schedule(crop_name:, variety:, stage_requirements:, agricultural_tasks:, output: nil, json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['schedule', '--crop-name', crop_name, '--variety', variety,
            '--stage-requirements', stage_requirements, '--agricultural-tasks', agricultural_tasks]
    args += ['--output', output] if output
    args << '--json' if json

    execute_command(args)
  end

  # Plan fertilizer applications
  def fertilize_plan(crop_file:, use_harvest_start: false, max_applications: 2, json: true)
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['fertilize', 'plan', '--crop-file', crop_file]
    args << '--use-harvest-start' if use_harvest_start
    # デフォルトで最大施用回数を2に制限
    args += ['--max-applications', max_applications.to_s] if max_applications
    args << '--json' if json

    execute_command(args)
  end

  # Get pest profile by pest name
  def pest_to_crop(pest:, crops:, language: 'ja')
    raise DaemonNotRunningError, 'AGRR daemon is not running' unless daemon_running?

    args = ['pest-to-crop', '--pest', pest, '--crops', crops, '--language', language]

    execute_command(args)
  end

  private

  def execute_command(args)
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
      clean_output || stdout
    elsif has_valid_json && stderr.blank?
      # Exit code is non-zero but we have valid JSON and no stderr
      # This is likely a warning in the daemon but the result is still valid
      Rails.logger.warn "⚠️ [AgrrService] Command returned exit code #{status.exitstatus} but has valid JSON output (likely warning)"
      clean_output || stdout
    else
      error_message = stderr.presence || "Command failed with exit code #{status.exitstatus}"
      Rails.logger.error "AGRR command failed: #{error_message}"
      raise CommandExecutionError, error_message
    end
  end
end
