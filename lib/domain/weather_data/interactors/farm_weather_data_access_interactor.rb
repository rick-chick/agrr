# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      # 農場に紐づく天気データ参照・予測キュー投入（Farms::WeatherDataController）。
      # clock は #today / #now に応答（通常 Time.zone）。
      class FarmWeatherDataAccessInteractor
        def initialize(output_port:,
                       farm_gateway:,
                       weather_data_gateway:,
                       enqueue_port:,
                       prediction_payload_parse:,
                       logger:,
                       clock:)
          @output_port = output_port
          @farm_gateway = farm_gateway
          @weather_data_gateway = weather_data_gateway
          @enqueue_port = enqueue_port
          @prediction_payload_parse = prediction_payload_parse
          @logger = logger
          @clock = clock
        end

        def call(input_dto)
          unless input_dto.is_a?(Domain::WeatherData::Dtos::FarmWeatherDataAccessInputDto)
            raise ArgumentError, "input_dto must be FarmWeatherDataAccessInputDto"
          end

          ctx = if input_dto.is_admin
                  @farm_gateway.farm_weather_data_access_context_for_admin_lookup(
                    farm_id: input_dto.farm_id
                  )
                else
                  @farm_gateway.farm_weather_data_access_context_for_owned_farm(
                    user_id: input_dto.user_id,
                    farm_id: input_dto.farm_id
                  )
                end
          return @output_port.on_farm_not_found if ctx.nil?

          if input_dto.predict
            predict_flow(ctx)
          else
            index_flow(ctx, input_dto)
          end
        end

        private

        def index_flow(ctx, input_dto)
          @logger.info "🔍 Weather data request for Farm##{ctx.farm_id} (#{ctx.latitude}, #{ctx.longitude})"

          end_date = input_dto.end_date || @clock.today
          # 1 年分は Date#<<（ActiveSupport の duration ではない）
          start_date = input_dto.start_date || (end_date << 12)
          @logger.info "   Period: #{start_date} to #{end_date}"

          if ctx.weather_location_id.nil?
            @logger.error "❌ Farm##{ctx.farm_id} has no weather_location association"
            return @output_port.on_no_weather_location
          end

          wl_id = ctx.weather_location_id
          @logger.info "✅ Using WeatherLocation##{wl_id} for Farm##{ctx.farm_id}"

          data_count = @weather_data_gateway.weather_data_count(
            weather_location_id: wl_id,
            start_date: start_date,
            end_date: end_date
          )
          @logger.info "   Found #{data_count} weather records"

          if data_count.zero?
            @logger.warn "⚠️  No weather data in the requested period"
            total_data = @weather_data_gateway.weather_data_count(weather_location_id: wl_id)
            if total_data > 0
              earliest_date = @weather_data_gateway.earliest_date(weather_location_id: wl_id)
              latest_date = @weather_data_gateway.latest_date(weather_location_id: wl_id)
              @logger.info "   Available data period: #{earliest_date} to #{latest_date}"
            end
          end

          weather_data_dtos = @weather_data_gateway.weather_data_for_period(
            weather_location_id: wl_id,
            start_date: start_date,
            end_date: end_date
          )
          weather_data = weather_data_dtos.map do |dto|
            {
              date: dto.date,
              temperature_max: dto.temperature_max,
              temperature_min: dto.temperature_min,
              temperature_mean: dto.temperature_mean,
              precipitation: dto.precipitation
            }
          end

          filtered = weather_data.filter_map do |datum|
            next if datum[:temperature_max].nil? || datum[:temperature_min].nil?

            temp_mean = datum[:temperature_mean]
            temp_mean = (datum[:temperature_max] + datum[:temperature_min]) / 2.0 if temp_mean.nil?

            {
              date: datum[:date],
              temperature_max: datum[:temperature_max].to_f,
              temperature_min: datum[:temperature_min].to_f,
              temperature_mean: temp_mean.to_f,
              precipitation: (datum[:precipitation] || 0.0).to_f
            }
          end

          @output_port.on_index_success(
            farm: {
              id: ctx.farm_id,
              name: ctx.display_name,
              latitude: ctx.latitude,
              longitude: ctx.longitude
            },
            period: {
              start_date: start_date,
              end_date: end_date
            },
            data: filtered
          )
        end

        def predict_flow(ctx)
          @logger.info "🔮 Weather prediction request for Farm##{ctx.farm_id}"

          prediction_hash = ctx.predicted_weather_data
          if prediction_hash.is_a?(Hash) && prediction_hash["data"].present?
            predicted_at = @prediction_payload_parse.predicted_at_from_payload(prediction_hash["predicted_at"])
            prediction_start = @prediction_payload_parse.prediction_start_date_from_payload(
              prediction_hash["prediction_start_date"]
            )

            stale_after_seconds = 24 * 60 * 60
            is_outdated = predicted_at.nil? ||
                          (@clock.now - predicted_at) > stale_after_seconds ||
                          prediction_start.nil? ||
                          prediction_start < @clock.today

            if is_outdated
              @logger.info "⚠️ [Farm##{ctx.farm_id}] Prediction data is outdated (predicted_at: #{predicted_at}), re-predicting..."
              @farm_gateway.update_predicted_weather_data(ctx.farm_id, nil)
            else
              @logger.info "✅ [Farm##{ctx.farm_id}] Returning cached prediction data (#{prediction_hash['data'].count} days, predicted_at: #{predicted_at})"

              filtered_data = prediction_hash["data"].filter_map do |datum|
                next if datum["temperature_max"].nil? || datum["temperature_min"].nil?

                temp_mean = datum["temperature_mean"]
                temp_mean = (datum["temperature_max"] + datum["temperature_min"]) / 2.0 if temp_mean.nil?

                {
                  date: datum["date"],
                  temperature_max: datum["temperature_max"].to_f,
                  temperature_min: datum["temperature_min"].to_f,
                  temperature_mean: temp_mean.to_f,
                  precipitation: (datum["precipitation"] || 0.0).to_f
                }
              end

              return @output_port.on_prediction_cached_success(
                farm: {
                  id: ctx.farm_id,
                  name: ctx.display_name,
                  latitude: ctx.latitude,
                  longitude: ctx.longitude
                },
                period: {
                  start_date: prediction_hash["prediction_start_date"],
                  end_date: prediction_hash["prediction_end_date"]
                },
                is_prediction: true,
                predicted_at: prediction_hash["predicted_at"],
                model: prediction_hash["model"],
                data: filtered_data
              )
            end
          end

          if ctx.weather_location_id.nil?
            @logger.error "❌ Farm##{ctx.farm_id} has no weather_location association"
            return @output_port.on_no_weather_location
          end

          wl_id = ctx.weather_location_id
          end_date = @clock.today
          start_date = end_date << 24

          historical_data_count = @weather_data_gateway.historical_data_count(
            weather_location_id: wl_id,
            start_date: start_date,
            end_date: end_date
          )

          required_days = (start_date..end_date).count
          if historical_data_count < required_days
            return @output_port.on_insufficient_historical_data
          end

          result = @enqueue_port.enqueue_predict_weather_standalone(
            farm_id: ctx.farm_id,
            days: nil,
            model: "lightgbm",
            target_end_date: nil,
            cultivation_plan_id: nil,
            channel_class: nil
          )

          unless result.ok
            return @output_port.on_enqueue_failed(error_message: result.error_message)
          end

          @logger.info "✅ [Farm##{ctx.farm_id}] Weather prediction job queued"
          @output_port.on_prediction_queued(farm_id: ctx.farm_id, farm_name: ctx.display_name)
        end
      end
    end
  end
end
