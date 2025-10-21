    def transform_predictions_to_weather_data(prediction_result, historical_data)
      # 履歴データから統計値を計算（降水量などの補完用）
      stats = calculate_historical_stats(historical_data['data'])
      
      # 予測データを完全な天気データ形式に変換
      weather_data = prediction_result['predictions'].map do |prediction|
        # 新フォーマット対応：temperature_max/temperature_min が含まれているか確認
        if prediction['temperature_max'] && prediction['temperature_min']
          # ✅ LightGBMマルチメトリック予測（新フォーマット）
          # モデルが予測した値をそのまま使用（飽和問題を解決）
          predicted_temp_mean = prediction['temperature'] || prediction['predicted_value']
          temp_max = prediction['temperature_max']
          temp_min = prediction['temperature_min']
          
          Rails.logger.debug "🆕 [AGRR] Using multi-metric predictions (temp_max: #{temp_max}, temp_min: #{temp_min})"
        else
          # ❌ 従来フォーマット（predicted_valueのみ）
          # 平均気温から最高気温・最低気温を推定（飽和する）
          predicted_temp_mean = prediction['predicted_value']
          temp_max = predicted_temp_mean + stats[:temp_range_half]
          temp_min = predicted_temp_mean - stats[:temp_range_half]
          
          Rails.logger.debug "📊 [AGRR] Using legacy format (estimated temp_max/min)"
        end
        
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
