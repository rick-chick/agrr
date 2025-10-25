# frozen_string_literal: true

require 'tempfile'

module Agrr
  class BaseGatewayV2
    class ExecutionError < StandardError; end
    class ParseError < StandardError; end
    class NoAllocationCandidatesError < StandardError; end
    
    def initialize
      @agrr_service = AgrrService.new
    end
    
    private
    
    def execute_command(*args, parse_json: true, timeout: 600)
      Rails.logger.info "🔧 [AGRR] Executing: #{args.join(' ')}"
      Rails.logger.info "⏱️ [AGRR] Timeout: #{timeout}s"
      
      # Extract command and arguments
      command = args[1] # Skip the binary path
      command_args = args[2..-1] # Skip binary path and command
      
      Rails.logger.info "🔍 [AGRR] Command: #{command}, Args: #{command_args.join(' ')}"
      
      begin
        result = case command
        when 'weather'
          execute_weather_command(command_args)
        when 'forecast'
          execute_forecast_command(command_args)
        when 'crop'
          execute_crop_command(command_args)
        when 'progress'
          execute_progress_command(command_args)
        when 'optimize'
          execute_optimize_command(command_args)
        when 'predict'
          execute_predict_command(command_args)
        else
          raise ExecutionError, "Unsupported command: #{command}"
        end
        
        Rails.logger.info "✅ [AGRR] Command completed successfully"
        Rails.logger.info "🔍 [AGRR] Result type: #{result.class}, Result: #{result.inspect[0..200]}..."
        
        return result unless parse_json
        
        # Parse JSON if needed
        if result.is_a?(String)
          json_content = extract_json_from_output(result)
          JSON.parse(json_content)
        else
          result
        end
        
      rescue AgrrService::DaemonNotRunningError => e
        Rails.logger.error "❌ [AGRR] Daemon not running: #{e.message}"
        raise ExecutionError, "AGRR daemon is not running: #{e.message}"
      rescue AgrrService::CommandExecutionError => e
        Rails.logger.error "❌ [AGRR] Command execution failed: #{e.message}"
        
        # Check for specific error patterns
        if e.message.include?('No valid allocation candidates could be generated')
          raise NoAllocationCandidatesError, e.message
        end
        
        if e.message.include?('overlap') && e.message.include?('fallow period')
          raise ExecutionError, e.message
        end
        
        raise ExecutionError, e.message
      rescue JSON::ParserError => e
        Rails.logger.error "❌ [AGRR] Failed to parse JSON: #{e.message}"
        raise ParseError, "Failed to parse JSON: #{e.message}"
      end
    end
    
    def execute_weather_command(args)
      # Parse weather command arguments
      location = nil
      start_date = nil
      end_date = nil
      days = nil
      data_source = 'jma'
      
      i = 0
      while i < args.length
        case args[i]
        when '--location'
          location = args[i + 1]
          i += 2
        when '--start-date'
          start_date = args[i + 1]
          i += 2
        when '--end-date'
          end_date = args[i + 1]
          i += 2
        when '--days'
          days = args[i + 1].to_i
          i += 2
        when '--data-source'
          data_source = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Location is required" unless location
      
      @agrr_service.weather(
        location: location,
        start_date: start_date,
        end_date: end_date,
        days: days,
        data_source: data_source,
        json: true
      )
    end
    
    def execute_forecast_command(args)
      location = nil
      
      i = 0
      while i < args.length
        case args[i]
        when '--location'
          location = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Location is required" unless location
      
      @agrr_service.forecast(location: location, json: true)
    end
    
    def execute_crop_command(args)
      query = nil
      
      i = 0
      while i < args.length
        case args[i]
        when '--query'
          query = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Query is required" unless query
      
      @agrr_service.crop(query: query, json: true)
    end
    
    def execute_progress_command(args)
      crop_file = nil
      start_date = nil
      weather_file = nil
      
      i = 0
      while i < args.length
        case args[i]
        when '--crop-file'
          crop_file = args[i + 1]
          i += 2
        when '--start-date'
          start_date = args[i + 1]
          i += 2
        when '--weather-file'
          weather_file = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Crop file, start date, and weather file are required" unless crop_file && start_date && weather_file
      
      @agrr_service.progress(
        crop_file: crop_file,
        start_date: start_date,
        weather_file: weather_file
      )
    end
    
    def execute_optimize_command(args)
      subcommand = args[0]
      
      case subcommand
      when 'period'
        execute_optimize_period(args[1..-1])
      when 'allocate'
        execute_optimize_allocate(args[1..-1])
      when 'adjust'
        execute_optimize_adjust(args[1..-1])
      else
        raise ExecutionError, "Unsupported optimize subcommand: #{subcommand}"
      end
    end
    
    def execute_optimize_period(args)
      crop_file = nil
      evaluation_start = nil
      evaluation_end = nil
      weather_file = nil
      field_file = nil
      interaction_rules_file = nil
      
      i = 0
      while i < args.length
        case args[i]
        when '--crop-file'
          crop_file = args[i + 1]
          i += 2
        when '--evaluation-start'
          evaluation_start = args[i + 1]
          i += 2
        when '--evaluation-end'
          evaluation_end = args[i + 1]
          i += 2
        when '--weather-file'
          weather_file = args[i + 1]
          i += 2
        when '--field-file'
          field_file = args[i + 1]
          i += 2
        when '--interaction-rules-file'
          interaction_rules_file = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Required parameters missing" unless crop_file && evaluation_start && evaluation_end && weather_file && field_file
      
      @agrr_service.optimize_period(
        crop_file: crop_file,
        evaluation_start: evaluation_start,
        evaluation_end: evaluation_end,
        weather_file: weather_file,
        field_file: field_file,
        interaction_rules_file: interaction_rules_file
      )
    end
    
    def execute_optimize_allocate(args)
      fields_file = nil
      crops_file = nil
      planning_start = nil
      planning_end = nil
      weather_file = nil
      format = 'json'
      
      i = 0
      while i < args.length
        case args[i]
        when '--fields-file'
          fields_file = args[i + 1]
          i += 2
        when '--crops-file'
          crops_file = args[i + 1]
          i += 2
        when '--planning-start'
          planning_start = args[i + 1]
          i += 2
        when '--planning-end'
          planning_end = args[i + 1]
          i += 2
        when '--weather-file'
          weather_file = args[i + 1]
          i += 2
        when '--format'
          format = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Required parameters missing" unless fields_file && crops_file && planning_start && planning_end && weather_file
      
      @agrr_service.optimize_allocate(
        fields_file: fields_file,
        crops_file: crops_file,
        planning_start: planning_start,
        planning_end: planning_end,
        weather_file: weather_file,
        format: format
      )
    end
    
    def execute_optimize_adjust(args)
      current_allocation = nil
      moves = nil
      weather_file = nil
      fields_file = nil
      crops_file = nil
      planning_start = nil
      planning_end = nil
      format = 'json'
      
      i = 0
      while i < args.length
        case args[i]
        when '--current-allocation'
          current_allocation = args[i + 1]
          i += 2
        when '--moves'
          moves = args[i + 1]
          i += 2
        when '--weather-file'
          weather_file = args[i + 1]
          i += 2
        when '--fields-file'
          fields_file = args[i + 1]
          i += 2
        when '--crops-file'
          crops_file = args[i + 1]
          i += 2
        when '--planning-start'
          planning_start = args[i + 1]
          i += 2
        when '--planning-end'
          planning_end = args[i + 1]
          i += 2
        when '--format'
          format = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Required parameters missing" unless current_allocation && moves && weather_file && fields_file && crops_file && planning_start && planning_end
      
      @agrr_service.optimize_adjust(
        current_allocation: current_allocation,
        moves: moves,
        weather_file: weather_file,
        fields_file: fields_file,
        crops_file: crops_file,
        planning_start: planning_start,
        planning_end: planning_end,
        format: format
      )
    end
    
    def execute_predict_command(args)
      input = nil
      output = nil
      days = nil
      model = 'arima'
      
      i = 0
      while i < args.length
        case args[i]
        when '--input'
          input = args[i + 1]
          i += 2
        when '--output'
          output = args[i + 1]
          i += 2
        when '--days'
          days = args[i + 1].to_i
          i += 2
        when '--model'
          model = args[i + 1]
          i += 2
        else
          i += 1
        end
      end
      
      raise ArgumentError, "Input, output, and days are required" unless input && output && days
      
      @agrr_service.predict(
        input: input,
        output: output,
        days: days,
        model: model
      )
    end
    
    # stdoutからJSONの部分だけを抽出する
    def extract_json_from_output(output)
      return output unless output.is_a?(String)
      
      Rails.logger.info "🔍 [AGRR] Extracting JSON from output (length: #{output.length})"
      Rails.logger.info "🔍 [AGRR] Output preview: #{output[0..200]}..."
      
      # Check if the output contains error messages
      if output.include?("Error:") || output.include?("❌")
        Rails.logger.error "❌ [AGRR] AGRR daemon returned error message: #{output.strip}"
        raise ExecutionError, "AGRR daemon error: #{output.strip}"
      end
      
      # Check if output already looks like JSON (starts with { or [)
      if output.strip.start_with?('{') || output.strip.start_with?('[')
        Rails.logger.info "✅ [AGRR] Output appears to be valid JSON"
        return output.strip
      end
      
      # AGRRコマンドがエラーを出力した場合の処理
      if output.include?("Error optimizing crop allocation:") || output.include?("No valid allocation candidates could be generated")
        Rails.logger.error "❌ [AGRR] AGRR command failed with allocation error"
        Rails.logger.error "❌ [AGRR] Error output: #{output}"
        
        # エラーメッセージから詳細を抽出
        error_message = extract_error_message(output)
        raise ExecutionError, "AGRR allocation failed: #{error_message}"
      end
      
      # AGRR progressコマンドがテキスト形式の出力を返す場合の処理
      if output.include?("Final Progress:") && output.include?("Total GDD Accumulated:")
        Rails.logger.warn "⚠️ [AGRR] AGRR returned text format instead of JSON, attempting to parse"
        
        # テキスト形式の出力から進捗データを抽出
        progress_data = parse_text_progress_output(output)
        if progress_data
          Rails.logger.info "✅ [AGRR] Successfully parsed text output to JSON"
          return progress_data.to_json
        else
          Rails.logger.error "❌ [AGRR] Failed to parse text output"
          raise ExecutionError, "Failed to parse AGRR text output"
        end
      end
      
      # 最初の { を見つける
      start_index = output.index('{')
      if start_index.nil?
        Rails.logger.error "❌ [AGRR] No JSON object found in output"
        Rails.logger.error "❌ [AGRR] Full output: #{output}"
        Rails.logger.error "❌ [AGRR] Output length: #{output.length}"
        Rails.logger.error "❌ [AGRR] First 500 chars: #{output[0..500]}"
        Rails.logger.error "❌ [AGRR] Last 500 chars: #{output[-500..-1]}"
        raise ExecutionError, "No JSON object found in AGRR output"
      end
      
      Rails.logger.info "🔍 [AGRR] Found JSON start at index: #{start_index}"
      
      # 最初の { から最後まで取得
      json_part = output[start_index..-1]
      
      # 最後の } を見つける
      end_index = json_part.rindex('}')
      if end_index.nil?
        Rails.logger.error "❌ [AGRR] No closing brace found in JSON"
        Rails.logger.error "❌ [AGRR] JSON part: #{json_part}"
        raise ExecutionError, "No closing brace found in AGRR JSON output"
      end
      
      # { から } までを抽出
      extracted_json = json_part[0..end_index]
      Rails.logger.info "✅ [AGRR] Extracted JSON (length: #{extracted_json.length})"
      extracted_json
    end
    
    # テキスト形式の進捗出力をパースしてJSON形式に変換
    def parse_text_progress_output(output)
      lines = output.split("\n")
      
      # 最終進捗とGDD情報を抽出
      final_progress = nil
      total_gdd = nil
      required_gdd = nil
      
      lines.each do |line|
        if line.include?("Final Progress:")
          final_progress = line.scan(/(\d+\.?\d*)%/).first&.first&.to_f
        elsif line.include?("Total GDD Accumulated:")
          gdd_match = line.scan(/(\d+\.?\d*)\s*\/\s*(\d+\.?\d*)/).first
          if gdd_match
            total_gdd = gdd_match[0].to_f
            required_gdd = gdd_match[1].to_f
          end
        end
      end
      
      # 日付と進捗データを抽出
      progress_records = []
      current_date = nil
      
      lines.each do |line|
        # 日付行を検出（YYYY-MM-DD形式）
        date_match = line.match(/^(\d{4}-\d{2}-\d{2})/)
        if date_match
          current_date = date_match[1]
        elsif current_date && line.include?("生育期")
          # 進捗データ行を解析
          parts = line.split(/\s+/)
          if parts.length >= 4
            gdd = parts[2].to_f rescue 0.0
            progress_percentage = parts[3].gsub('%', '').to_f rescue 0.0
            
            progress_records << {
              "date" => "#{current_date}T00:00:00",
              "cumulative_gdd" => gdd,
              "total_required_gdd" => required_gdd || 1000.0,
              "growth_percentage" => progress_percentage / 100.0,
              "stage_name" => "生育期",
              "is_complete" => progress_percentage >= 100.0
            }
          end
        end
      end
      
      # JSON形式のデータを構築
      {
        "crop_name" => "作物",
        "variety" => "品種",
        "start_date" => progress_records.first&.dig("date") || "2024-01-01T00:00:00",
        "progress_records" => progress_records,
        "yield_factor" => 1.0,
        "yield_loss_percentage" => 0.0,
        "total_gdd" => total_gdd,
        "final_progress" => final_progress
      }
    end
    
    def write_temp_file(data, prefix: 'agrr_data')
      file = Tempfile.new([prefix, '.json'])
      file.write(data.to_json)
      file.flush
      file
    end
    
    def extract_error_message(output)
      # エラーメッセージの最初の行を抽出
      lines = output.split("\n")
      error_line = lines.find { |line| line.include?("Error optimizing crop allocation:") }
      
      if error_line
        # "Error optimizing crop allocation: " 以降の部分を取得
        error_line.split("Error optimizing crop allocation: ")[1] || "Unknown allocation error"
      else
        "AGRR allocation failed - no valid candidates generated"
      end
    end
  end
end
