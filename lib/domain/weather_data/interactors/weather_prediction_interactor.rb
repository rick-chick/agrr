# frozen_string_literal: true

# 天気予測（CultivationPlan / Farm への保存を含む）。
# T-032: app/services から domain interactors へ移行。
# WeatherLocation / Farm / CultivationPlan は DTO のみ受け取る（禁止3: AR をコア入力にしない）。
# `Date.current` を何度読むか（境界が変わらない順序）まで旧実装に揃える（同一リクエスト内の日またぎと同じ）。
module Domain
  module WeatherData
    module Interactors
      class WeatherPredictionInteractor
        class WeatherDataNotFoundError < StandardError; end
        class InsufficientPredictionDataError < StandardError; end

        BENCHMARK_ENABLED = ENV.fetch("WEATHER_BENCHMARK", "false") != "false"

        REQUIRED_WEATHER_LOCATION_READERS = %i[id latitude longitude elevation timezone predicted_weather_data].freeze
        REQUIRED_FARM_READERS = %i[id weather_location_id predicted_weather_data].freeze
        REQUIRED_PLAN_WEATHER_READERS = %i[id prediction_target_end_date calculated_planning_end_date predicted_weather_data].freeze

        # @param clock [#today, #now] アプリ TZ の「カレンダー日」とインスタント（CompositionRoot で Time.zone を渡す想定）。
        # @param anchors_resolver [#anchors_for] 訓練窓・当年履歴・既定予測終了（Rails はアダプタで計算。禁止4）。
        def initialize(weather_location:, farm: nil,
                       cultivation_plan_gateway:,
                       farm_gateway:,
                       weather_data_gateway:,
                       prediction_gateway:,
                       logger:,
                       clock:,
                       anchors_resolver:)
          raise ArgumentError, "weather_location is required" unless weather_location
          unless clock.respond_to?(:today) && clock.respond_to?(:now)
            raise ArgumentError, "clock must respond to :today and :now"
          end
          unless anchors_resolver.respond_to?(:anchors_for)
            raise ArgumentError, "anchors_resolver must respond to :anchors_for"
          end
          unless weather_location.is_a?(Domain::WeatherData::Contracts::WeatherLocationPredictionInput)
            raise ArgumentError, "weather_location must include Domain::WeatherData::Contracts::WeatherLocationPredictionInput (WeatherLocation を利用可)"
          end
          assert_weather_location_shape!(weather_location)
          if farm && !farm.is_a?(Domain::WeatherData::Contracts::FarmWeatherPredictionInput)
            raise ArgumentError, "farm must include Domain::WeatherData::Contracts::FarmWeatherPredictionInput (FarmWeatherPrediction を利用可)"
          end
          assert_farm_shape!(farm) if farm

          if farm&.weather_location_id && farm.weather_location_id != weather_location.id
            raise ArgumentError, "farm.weather_location does not match provided weather_location"
          end

          @weather_location = weather_location
          @farm = farm
          @prediction_gateway = prediction_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @farm_gateway = farm_gateway
          @weather_data_gateway = weather_data_gateway
          @logger = logger
          @clock = clock
          @anchors_resolver = anchors_resolver
        end

        # 天気予測を実行してCultivationPlanに保存
        # @param plan_weather [Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput]
        #   具象クラスは {Domain::WeatherData::Dtos::CultivationPlanWeather}
        # @param target_end_date [Date] 予測終了日（デフォルト: 計画由来の終了日）
        # @return [Hash] 予測データとメタ情報
        def predict_for_cultivation_plan(plan_weather:, target_end_date: nil)
          unless plan_weather.is_a?(Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput)
            raise ArgumentError, "plan_weather must include Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput (CultivationPlanWeather を利用可)"
          end
          assert_cultivation_plan_weather_shape!(plan_weather)

          default_target = plan_weather.prediction_target_end_date || plan_weather.calculated_planning_end_date
          target_end_date = normalize_target_end_date(target_end_date || default_target)

          weather_info = prepare_weather_data(target_end_date)
          payload = build_prediction_payload(weather_info, target_end_date)

          if BENCHMARK_ENABLED
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            persist_prediction_payload(payload)
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            @logger.debug "🕒 [WeatherPrediction][benchmark] persist_prediction_payload: #{elapsed.round(4)}s"
          else
            persist_prediction_payload(payload)
          end

          @cultivation_plan_gateway.update_predicted_weather_data(plan_weather.id, payload)

          weather_info
        end

        # 天気予測を実行してFarmに保存
        # @param target_end_date [Date, nil] 予測終了日。nil のとき anchors の default_target_end_date（従来: 参照日 + 6.months）
        # @return [Hash] 予測データとメタ情報
        def predict_for_farm(target_end_date: nil)
          raise ArgumentError, "farm is required to save prediction" unless @farm

          target_end_date = normalize_target_end_date(target_end_date)

          weather_info = prepare_weather_data(target_end_date)
          payload = build_prediction_payload(weather_info, target_end_date)

          persist_prediction_payload(payload)

          @farm_gateway.update_predicted_weather_data(@farm.id, payload)

          weather_info
        end

        # 既存の予測データを取得（新規予測は実行しない）
        # @param target_end_date [Date] 必要な予測終了日
        # @param cultivation_plan_weather [Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput, nil]
        #   具象クラスは {Domain::WeatherData::Dtos::CultivationPlanWeather}
        # @return [Hash] 予測データとメタ情報
        def get_existing_prediction(target_end_date: nil, cultivation_plan_weather: nil)
          if cultivation_plan_weather && !cultivation_plan_weather.is_a?(Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput)
            raise ArgumentError, "cultivation_plan_weather must be nil or include Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput"
          end
          assert_cultivation_plan_weather_shape!(cultivation_plan_weather) if cultivation_plan_weather

          default_target = if cultivation_plan_weather
            cultivation_plan_weather.prediction_target_end_date || cultivation_plan_weather.calculated_planning_end_date
          else
            nil
          end
          target_end_date ||= default_target
          target_end_date = normalize_target_end_date(target_end_date)

          location_result = cached_prediction_result(@weather_location.predicted_weather_data, target_end_date)
          return location_result if location_result

          if cultivation_plan_weather && cultivation_plan_weather.predicted_weather_data.present? && cultivation_plan_weather.predicted_weather_data["data"].present?
            plan_result = cached_prediction_result(cultivation_plan_weather.predicted_weather_data, target_end_date)
            return plan_result if plan_result
          end

          if @farm&.predicted_weather_data.present?
            farm_result = cached_prediction_result(@farm.predicted_weather_data, target_end_date)
            return farm_result if farm_result
          end

          nil
        end

        private

        def assert_weather_location_shape!(object)
          assert_responds_to_readers!(object, REQUIRED_WEATHER_LOCATION_READERS, "weather_location")
        end

        def assert_farm_shape!(object)
          assert_responds_to_readers!(object, REQUIRED_FARM_READERS, "farm")
        end

        def assert_cultivation_plan_weather_shape!(object)
          assert_responds_to_readers!(object, REQUIRED_PLAN_WEATHER_READERS, "plan_weather")
        end

        def assert_responds_to_readers!(object, readers, role)
          readers.each do |method_name|
            unless object.respond_to?(method_name)
              raise ArgumentError, "#{role} must respond_to?(:#{method_name}) for WeatherPredictionInteractor"
            end
          end
        end

        # prepare 〜 get_training〜get_current と、prediction_start での Today 評価を分ける（旧 Date.current を都度呼ぶ同等）。
        def prepare_weather_data(target_end_date)
          target_end_date = normalize_target_end_date(target_end_date)

          training_result = get_training_data
          training_data = training_result[:data]
          training_end_date = training_result[:end_date]
          current_year_data = get_current_year_data

          training_formatted = format_weather_data_for_agrr(training_data)

          if BENCHMARK_ENABLED
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            future = get_prediction_data(training_formatted, target_end_date, training_end_date)
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            @logger.debug "🕒 [WeatherPrediction][benchmark] get_prediction_data: #{elapsed.round(4)}s"
          else
            future = get_prediction_data(training_formatted, target_end_date, training_end_date)
          end

          current_year_formatted = format_weather_data_for_agrr(current_year_data)

          if BENCHMARK_ENABLED
            start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            merged_data = merge_weather_data(current_year_formatted, future)
            elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
            @logger.debug "🕒 [WeatherPrediction][benchmark] merge_weather_data: #{elapsed.round(4)}s"
          else
            merged_data = merge_weather_data(current_year_formatted, future)
          end

          merged_dates = Array(merged_data["data"]).map { |d| parse_date(d["time"]) }.compact
          merged_end_date = merged_dates.max
          if merged_end_date.nil? || merged_end_date < target_end_date
            message = "Merged weather data ends at #{merged_end_date}, but target_end_date is #{target_end_date}. AGRR prediction may be insufficient."
            @logger.error "❌ [WeatherPrediction] #{message}"
            raise InsufficientPredictionDataError, message
          end

          today_for_range = @clock.today
          prediction_start_date = ((training_end_date + 1) > today_for_range) ? training_end_date + 1 : today_for_range

          @logger.info "✅ [WeatherPrediction] Weather data prepared successfully"
          @logger.info "🧮 [WeatherPrediction] Prediction range prepared: start=#{prediction_start_date} end=#{target_end_date} (merged_end=#{merged_end_date})"

          {
            data: merged_data,
            target_end_date: target_end_date,
            prediction_start_date: prediction_start_date.to_s,
            prediction_days: merged_dates.count
          }
        end

        def get_training_data
          anchors = @anchors_resolver.anchors_for(@clock.today)
          training_start_date = anchors.training_start_date
          training_end_date = anchors.training_end_date
          training_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: @weather_location.id,
            start_date: training_start_date,
            end_date: training_end_date
          )

          if training_data.empty?
            raise WeatherDataNotFoundError,
                  "気象データがありません。期間 #{training_start_date} から #{training_end_date} の気象データが見つかりません。 " \
                  "管理者に気象データのインポートを依頼してください。"
          end

          minimum_required_days = 18 * 365

          if training_data.count < minimum_required_days
            raise WeatherDataNotFoundError,
                  "気象データが不足しています。現在 #{training_data.count} 件のデータがありますが、最低 #{minimum_required_days} 日分（約18年）のデータが必要です。 " \
                  "管理者に気象データのインポートを依頼してください（期間: #{training_start_date} から #{training_end_date}）。"
          end

          actual_training_end_date = training_data.map(&:date).max

          { data: training_data, end_date: actual_training_end_date }
        end

        def get_current_year_data
          anchors = @anchors_resolver.anchors_for(@clock.today)
          current_year_start = anchors.current_year_history_start_date
          current_year_end = anchors.current_year_history_end_date
          current_year_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: @weather_location.id,
            start_date: current_year_start,
            end_date: current_year_end
          )

          return [] if current_year_data.empty?

          current_year_data
        end

        def get_prediction_data(training_formatted, target_end_date, training_end_date)
          cached_future = cached_future_data(@weather_location.predicted_weather_data, target_end_date)
          return cached_future if cached_future

          cached_future = cached_future_data(@farm&.predicted_weather_data, target_end_date)
          return cached_future if cached_future

          prediction_start_date = training_end_date + 1
          prediction_days = (target_end_date - training_end_date).to_i

          @logger.info "🔮 [WeatherPrediction] Predicting weather from #{prediction_start_date} until #{target_end_date} (#{prediction_days} days)"

          future = @prediction_gateway.predict(
            historical_data: training_formatted,
            days: prediction_days,
            model: "lightgbm"
          )

          future_data = Array(future["data"])
          actual_prediction_days = future_data.count
          data_end = latest_payload_date(future_data)
          @logger.info "🧮 [WeatherPrediction] Prediction days: expected=#{prediction_days} returned=#{actual_prediction_days}, data_end=#{data_end}"

          if future["predictions"]
            sample_predictions = future["predictions"]
            @logger.info "🔍 [WeatherPrediction] AGRR predictions sample: first=#{sample_predictions.first(3).map { |p| p['date'] }}, last=#{sample_predictions.last(3).map { |p| p['date'] }}"
          end

          if actual_prediction_days < prediction_days
            message = "Expected #{prediction_days} days from #{prediction_start_date} to #{target_end_date}, but received #{actual_prediction_days} days."
            @logger.warn "⚠️ [WeatherPrediction] #{message}"
            raise InsufficientPredictionDataError, message
          end

          if data_end && data_end < target_end_date
            message = "Expected prediction to end at #{target_end_date}, but received data ending at #{data_end}."
            @logger.warn "⚠️ [WeatherPrediction] #{message}"
            raise InsufficientPredictionDataError, message
          end

          future
        end

        def format_weather_data_for_agrr(weather_data)
          wl = @weather_location
          {
            "latitude" => wl.latitude.to_f,
            "longitude" => wl.longitude.to_f,
            "elevation" => (wl.elevation || 0.0).to_f,
            "timezone" => wl.timezone,
            "data" => weather_data.filter_map do |datum|
              next if datum.temperature_max.nil? || datum.temperature_min.nil?

              temp_mean = datum.temperature_mean
              if temp_mean.nil?
                temp_mean = (datum.temperature_max.to_f + datum.temperature_min.to_f) / 2.0
              else
                temp_mean = temp_mean.to_f
              end

              {
                "time" => datum.date.to_s,
                "temperature_2m_max" => datum.temperature_max.to_f,
                "temperature_2m_min" => datum.temperature_min.to_f,
                "temperature_2m_mean" => temp_mean,
                "precipitation_sum" => (datum.precipitation || 0.0).to_f,
                "sunshine_duration" => datum.sunshine_hours ? (datum.sunshine_hours.to_f * 3600.0) : 0.0,
                "wind_speed_10m_max" => (datum.wind_speed || 0.0).to_f,
                "weather_code" => datum.weather_code || 0
              }
            end
          }
        end

        def merge_weather_data(historical, future)
          {
            "latitude" => historical["latitude"],
            "longitude" => historical["longitude"],
            "elevation" => historical["elevation"],
            "timezone" => historical["timezone"],
            "data" => historical["data"] + future["data"]
          }
        end

        def normalize_target_end_date(target_end_date)
          target_end_date || @anchors_resolver.anchors_for(@clock.today).default_target_end_date
        end

        def build_prediction_payload(weather_info, target_end_date)
          data = weather_info[:data]
          if data["data"].is_a?(Hash) && data["data"]["data"].is_a?(Array)
            data = data["data"]
          end

          data_end = latest_payload_date(Array(data["data"]))
          actual_end_date = data_end || target_end_date

          if data_end && data_end < target_end_date
            @logger.warn "⚠️ [WeatherPrediction] Prediction data ends at #{data_end}, but target_end_date is #{target_end_date}. AGRR may not be predicting for the full requested period."
          end

          stamped_at = @clock.now.iso8601

          (data || {}).merge(
            "generated_at" => stamped_at,
            "predicted_at" => stamped_at,
            "prediction_start_date" => weather_info[:prediction_start_date],
            "prediction_end_date" => actual_end_date.to_s,
            "target_end_date" => target_end_date.to_s,
            "model" => "lightgbm"
          )
        end

        def persist_prediction_payload(payload)
          return unless @weather_location

          @weather_data_gateway.update_predicted_weather_data(weather_location_id: @weather_location.id, payload: payload)
        end

        def cached_prediction_result(payload, target_end_date)
          return nil unless payload.present?

          prediction_start = parse_date(payload["prediction_start_date"])
          prediction_end = parse_date(payload["prediction_end_date"])
          return nil unless prediction_start
          data_array = Array(payload["data"])
          return nil if data_array.empty?
          data_end = latest_payload_date(data_array)

          if target_end_date && prediction_end && prediction_end < target_end_date
            return nil
          end
          if target_end_date && (!data_end || data_end < target_end_date)
            return nil
          end

          cached_prediction_days = compute_prediction_days(prediction_start, prediction_end || target_end_date || data_end)
          {
            data: payload,
            target_end_date: target_end_date || prediction_end,
            prediction_start_date: payload["prediction_start_date"],
            prediction_days: cached_prediction_days
          }
        end

        def cached_future_data(payload, target_end_date)
          return nil unless payload.present?

          prediction_start = parse_date(payload["prediction_start_date"])
          prediction_end = parse_date(payload["prediction_end_date"])
          return nil unless prediction_start

          if target_end_date && prediction_end && prediction_end < target_end_date
            return nil
          end

          data = Array(payload["data"])
          filtered = data.filter_map do |datum|
            datum_date = parse_date(datum["time"] || datum["date"])
            next unless datum_date
            next if datum_date < prediction_start
            next if target_end_date && datum_date > target_end_date

            normalize_prediction_datum(datum)
          end

          return nil if filtered.empty?
          if target_end_date
            data_end = latest_payload_date(filtered)
            if data_end.nil? || data_end < target_end_date
              return nil
            end
          end

          { "data" => filtered }
        end

        def normalize_prediction_datum(datum)
          time = datum["time"] || datum["date"]
          return nil unless time

          {
            "time" => time,
            "temperature_2m_max" => datum["temperature_2m_max"] || datum["temperature_max"],
            "temperature_2m_min" => datum["temperature_2m_min"] || datum["temperature_min"],
            "temperature_2m_mean" => datum["temperature_2m_mean"] || datum["temperature_mean"],
            "precipitation_sum" => datum["precipitation_sum"] || datum["precipitation"] || 0.0,
            "sunshine_duration" => datum["sunshine_duration"] || (datum["sunshine_hours"] ? datum["sunshine_hours"].to_f * 3600.0 : 0.0),
            "wind_speed_10m_max" => datum["wind_speed_10m_max"] || datum["wind_speed"] || 0.0,
            "weather_code" => datum["weather_code"] || 0
          }
        end

        def parse_date(value)
          return nil unless value

          Date.parse(value.to_s)
        rescue ArgumentError
          nil
        end

        def latest_payload_date(data_array)
          data_array.map do |datum|
            parse_date(datum["time"] || datum["date"])
          end.compact.max
        end

        def compute_prediction_days(prediction_start, prediction_end)
          return 0 unless prediction_start && prediction_end

          (prediction_end - prediction_start).to_i + 1
        end
      end
    end
  end
end
