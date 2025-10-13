# frozen_string_literal: true

module Agrr
  class PredictionGateway < BaseGateway
    def predict(historical_data:, days:)
      Rails.logger.info "🔮 [AGRR] Predicting weather for #{days} days"
      
      # 入力データの検証
      data_count = historical_data.dig('data')&.count || 0
      Rails.logger.info "📊 [AGRR] Input data: #{data_count} records"
      
      if data_count == 0
        raise ParseError, "Input historical data is empty"
      end
      
      input_file = write_temp_file(historical_data, prefix: 'weather_input')
      output_file = Tempfile.new(['weather_output', '.json'])
      
      # デバッグ用にファイルを保存
      debug_dir = Rails.root.join('tmp/debug')
      FileUtils.mkdir_p(debug_dir)
      debug_input_path = debug_dir.join("prediction_input_#{Time.current.to_i}.json")
      FileUtils.cp(input_file.path, debug_input_path)
      
      begin
        Rails.logger.info "📁 [AGRR] Input file: #{input_file.path} (#{File.size(input_file.path)} bytes)"
        Rails.logger.info "📁 [AGRR] Debug input saved to: #{debug_input_path}"
        Rails.logger.info "📁 [AGRR] Output file: #{output_file.path}"
        
        execute_command(
          agrr_path,
          'predict',
          '--input', input_file.path,
          '--output', output_file.path,
          '--days', days.to_s,
          parse_json: false
        )
        
        # 出力ファイルからJSONを読み込む
        output_file.rewind
        output_content = output_file.read
        
        # デバッグ用に出力ファイルも保存
        debug_output_path = debug_dir.join("prediction_output_#{Time.current.to_i}.json")
        File.write(debug_output_path, output_content)
        
        Rails.logger.info "📊 [AGRR] Output file size: #{output_content.bytesize} bytes"
        Rails.logger.info "📁 [AGRR] Debug output saved to: #{debug_output_path}"
        
        if output_content.empty?
          Rails.logger.error "❌ [AGRR] Output file is empty (command succeeded but produced no output)"
          Rails.logger.error "Input data sample (first 2 records): #{historical_data.dig('data')&.first(2)&.to_json}"
          raise ParseError, "Prediction output file is empty (command succeeded but produced no output)"
        end
        
        raw_result = JSON.parse(output_content)
        
        # AGRR予測結果を完全な天気データ形式に変換
        transformed_result = transform_predictions_to_weather_data(raw_result, historical_data)
        
        Rails.logger.info "✅ [AGRR] Prediction completed: #{transformed_result['data']&.count || 0} records"
        transformed_result
      rescue JSON::ParserError => e
        Rails.logger.error "❌ [AGRR] Failed to parse prediction output: #{e.message}"
        Rails.logger.error "Output content (first 500 chars): #{output_content&.first(500)}"
        raise ParseError, "Failed to parse prediction output: #{e.message}"
      ensure
        input_file.close
        input_file.unlink
        output_file.close
        output_file.unlink
      end
    end
    
    private
    
    def transform_predictions_to_weather_data(prediction_result, historical_data)
      # 履歴データから統計値を計算
      stats = calculate_historical_stats(historical_data['data'])
      
      # 予測データを完全な天気データ形式に変換
      weather_data = prediction_result['predictions'].map do |prediction|
        predicted_temp_mean = prediction['predicted_value']
        
        # 平均気温から最高気温・最低気温を推定
        # 履歴データの平均的な日較差を使用
        temp_max = predicted_temp_mean + stats[:temp_range_half]
        temp_min = predicted_temp_mean - stats[:temp_range_half]
        
        {
          'time' => prediction['date'].split('T').first,
          'temperature_2m_max' => temp_max.to_f.round(2),
          'temperature_2m_min' => temp_min.to_f.round(2),
          'temperature_2m_mean' => predicted_temp_mean.to_f.round(2),
          'precipitation_sum' => stats[:avg_precipitation].to_f.round(2),
          'sunshine_duration' => stats[:avg_sunshine].to_f.round(2),
          'wind_speed_10m_max' => stats[:avg_wind_speed].to_f.round(2),
          'weather_code' => 0  # 晴れを仮定
        }
      end
      
      {
        'data' => weather_data
      }
    end
    
    def calculate_historical_stats(historical_data_array)
      return default_stats if historical_data_array.empty?
      
      # 日較差の平均（最高気温と最低気温の差の半分）
      temp_ranges = historical_data_array.map do |d|
        next nil unless d['temperature_2m_max'] && d['temperature_2m_min']
        (d['temperature_2m_max'] - d['temperature_2m_min']) / 2.0
      end.compact
      
      {
        temp_range_half: temp_ranges.empty? ? 7.0 : (temp_ranges.sum / temp_ranges.size),
        avg_precipitation: calculate_avg(historical_data_array, 'precipitation_sum', 0.0),
        avg_sunshine: calculate_avg(historical_data_array, 'sunshine_duration', 28800.0),  # 8時間
        avg_wind_speed: calculate_avg(historical_data_array, 'wind_speed_10m_max', 3.0)
      }
    end
    
    def calculate_avg(data_array, field, default_value)
      values = data_array.map { |d| d[field] }.compact
      values.empty? ? default_value : (values.sum / values.size)
    end
    
    def default_stats
      {
        temp_range_half: 7.0,  # 日較差±7℃
        avg_precipitation: 0.0,  # 降水量0mm
        avg_sunshine: 28800.0,  # 8時間（秒）
        avg_wind_speed: 3.0  # 風速3m/s
      }
    end
  end
end

