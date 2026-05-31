# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      class PredictionDaemonGateway < BaseGatewayV2
        def predict(historical_data:, days:, model: "lightgbm")
          effective_model = resolve_effective_model(model)

          if effective_model == "mock"
            Rails.logger.info "🔮 [AGRR] Using MOCK model (effective_model=mock)"
            return generate_mock_predictions(historical_data, days)
          end

          Rails.logger.info "🔮 [AGRR] Predicting weather for #{days} days using #{effective_model.upcase} model"

          # 入力データの検証
          data_count = historical_data.dig("data")&.count || 0
          Rails.logger.info "📊 [AGRR] Input data: #{data_count} records"

          if data_count == 0
            raise ParseError, "Input historical data is empty"
          end

          input_file = write_temp_file(historical_data, prefix: "weather_input")
          output_file = Tempfile.new([ "weather_output", ".json" ])
          output_file.close # AGRRコマンドが書き込めるようにファイルを閉じる
          output_path = output_file.path

          # デバッグ用にファイルを保存（本番環境以外のみ）
          unless Rails.env.production?
            debug_dir = Rails.root.join("tmp/debug")
            FileUtils.mkdir_p(debug_dir)
            debug_input_path = debug_dir.join("prediction_input_#{Time.current.to_i}.json")
            FileUtils.cp(input_file.path, debug_input_path)
            Rails.logger.info "📁 [AGRR] Debug input saved to: #{debug_input_path}"
          end

          begin
            Rails.logger.info "📁 [AGRR] Input file: #{input_file.path} (#{File.size(input_file.path)} bytes)"
            Rails.logger.info "📁 [AGRR] Output file: #{output_path}"

            # LightGBMの場合は、明示的に全ての気温メトリックを指定
            # 予測処理は時間がかかるため、タイムアウトを30分に設定
            prediction_timeout = 1800  # 30 minutes

            if effective_model == "lightgbm"
              execute_command(
                "dummy_path", # Not used in V2
                "predict",
                "--input", input_file.path,
                "--output", output_path,
                "--days", days.to_s,
                "--model", effective_model,
                "--metrics", "temperature,temperature_max,temperature_min",
                parse_json: false,
                timeout: prediction_timeout
              )
            elsif effective_model == "mock"
              execute_command(
                "dummy_path", # Not used in V2
                "predict",
                "--input", input_file.path,
                "--output", output_path,
                "--days", days.to_s,
                "--model", effective_model,
                parse_json: false,
                timeout: prediction_timeout
              )
            else
              execute_command(
                "dummy_path", # Not used in V2
                "predict",
                "--input", input_file.path,
                "--output", output_path,
                "--days", days.to_s,
                "--model", effective_model,
                parse_json: false,
                timeout: prediction_timeout
              )
            end

            # 出力ファイルからJSONを読み込む
            output_content = File.read(output_path)

            # デバッグ用に出力ファイルも保存（本番環境以外のみ）
            unless Rails.env.production?
              debug_dir = Rails.root.join("tmp/debug")
              debug_output_path = debug_dir.join("prediction_output_#{Time.current.to_i}.json")
              File.write(debug_output_path, output_content)
              Rails.logger.info "📁 [AGRR] Debug output saved to: #{debug_output_path}"
            end

            Rails.logger.info "📊 [AGRR] Output file size: #{output_content.bytesize} bytes"

            if output_content.empty?
              Rails.logger.error "❌ [AGRR] Output file is empty (command succeeded but produced no output)"
              Rails.logger.error "Input data sample (first 2 records): #{historical_data.dig('data')&.first(2)&.to_json}"
              raise ParseError, "Prediction output file is empty (command succeeded but produced no output)"
            end

            raw_result = JSON.parse(output_content)
            predictions_count = raw_result["predictions"]&.count || 0
            Rails.logger.info "📊 [AGRR] Raw predictions count: #{predictions_count}"

            # AGRR予測結果を完全な天気データ形式に変換
            transformed_result = transform_predictions_to_weather_data(raw_result, historical_data)

            # デバッグ用に変換後のデータも保存（本番環境以外のみ）
            unless Rails.env.production?
              debug_dir = Rails.root.join("tmp/debug")
              debug_transformed_path = debug_dir.join("prediction_transformed_#{Time.current.to_i}.json")
              File.write(debug_transformed_path, transformed_result.to_json)
              Rails.logger.info "📁 [AGRR] Debug transformed saved to: #{debug_transformed_path}"
            end

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

        # 優先順位: AGRR_PREDICT_MODEL > (development かつ AGRR_USE_MOCK=true なら mock) > 引数 model
        def resolve_effective_model(model)
          env_model = ENV["AGRR_PREDICT_MODEL"]&.strip&.downcase
          return env_model if env_model.present?

          if Rails.env.development? && ENV["AGRR_USE_MOCK"] == "true"
            "mock"
          else
            model
          end
        end

        def generate_mock_predictions(historical_data, days)
          Rails.logger.info "🎭 [AGRR] Generating mock predictions for #{days} days"

          # 履歴データから統計値を計算
          stats = calculate_historical_stats(historical_data["data"])

          # 現在の日付から指定日数分の予測データを生成
          start_date = Date.current
          mock_predictions = (0...days).map do |i|
            date = start_date + i.days

            # 季節性を考慮した気温の生成
            day_of_year = date.yday
            seasonal_temp = 15.0 + 10.0 * Math.sin(2 * Math::PI * (day_of_year - 80) / 365.0)

            # ランダムな変動を追加
            random_variation = (rand - 0.5) * 5.0
            base_temp = seasonal_temp + random_variation

            # 最高気温・最低気温・平均気温を生成
            temp_max = base_temp + 5.0 + rand(3.0)
            temp_min = base_temp - 5.0 - rand(3.0)
            temp_mean = (temp_max + temp_min) / 2.0

            {
              "time" => date.to_s,
              "temperature_2m_max" => temp_max.round(2),
              "temperature_2m_min" => temp_min.round(2),
              "temperature_2m_mean" => temp_mean.round(2),
              "precipitation_sum" => rand < 0.3 ? rand(10.0).round(2) : 0.0, # 30%の確率で降水
              "sunshine_duration" => (6.0 + rand(4.0)) * 3600.0, # 6-10時間の日照時間
              "wind_speed_10m_max" => (2.0 + rand(5.0)).round(2),
              "weather_code" => rand < 0.7 ? 0 : 61 # 70%の確率で晴れ
            }
          end

          {
            "data" => mock_predictions
          }
        end

        def transform_predictions_to_weather_data(prediction_result, historical_data)
          # 履歴データから統計値を計算
          stats = calculate_historical_stats(historical_data["data"])

          # 予測データを完全な天気データ形式に変換
          weather_data = prediction_result["predictions"].map do |prediction|
            # 新フォーマット対応：temperature_max/temperature_min が含まれているか確認
            if prediction["temperature_max"] && prediction["temperature_min"]
              # ✅ LightGBMマルチメトリック予測（新フォーマット）
              # モデルが予測した値をそのまま使用（飽和問題を解決）
              predicted_temp_mean = prediction["temperature"] || prediction["predicted_value"]
              temp_max = prediction["temperature_max"]
              temp_min = prediction["temperature_min"]
            else
              # ❌ 従来フォーマット（predicted_valueのみ）
              # 平均気温から最高気温・最低気温を推定（飽和する）
              predicted_temp_mean = prediction["predicted_value"]
              temp_max = predicted_temp_mean + stats[:temp_range_half]
              temp_min = predicted_temp_mean - stats[:temp_range_half]
            end

            {
              "time" => prediction["date"].split("T").first,
              "temperature_2m_max" => temp_max.to_f.round(2),
              "temperature_2m_min" => temp_min.to_f.round(2),
              "temperature_2m_mean" => predicted_temp_mean.to_f.round(2),
              "precipitation_sum" => stats[:avg_precipitation].to_f.round(2),
              "sunshine_duration" => stats[:avg_sunshine].to_f.round(2),
              "wind_speed_10m_max" => stats[:avg_wind_speed].to_f.round(2),
              "weather_code" => 0  # 晴れを仮定
            }
          end

          {
            "data" => weather_data
          }
        end

        def calculate_historical_stats(historical_data_array)
          return default_stats if historical_data_array.empty?

          # 日較差の平均（最高気温と最低気温の差の半分）
          temp_ranges = historical_data_array.map do |d|
            next nil unless d["temperature_2m_max"] && d["temperature_2m_min"]
            (d["temperature_2m_max"] - d["temperature_2m_min"]) / 2.0
          end.compact

          {
            temp_range_half: temp_ranges.empty? ? 7.0 : (temp_ranges.sum / temp_ranges.size),
            avg_precipitation: calculate_avg(historical_data_array, "precipitation_sum", 0.0),
            avg_sunshine: calculate_avg(historical_data_array, "sunshine_duration", 28800.0),  # 8時間
            avg_wind_speed: calculate_avg(historical_data_array, "wind_speed_10m_max", 3.0)
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
  end
end
