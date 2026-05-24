# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateWeatherActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateWeatherGateway
        def initialize(logger:, translator:, weather_prediction_service_factory:, weather_data_gateway:,
                       cultivation_plan_gateway:, prediction_gateway:)
          @logger = logger
          @translator = translator
          @weather_prediction_service_factory = weather_prediction_service_factory
          @weather_data_gateway = weather_data_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @prediction_gateway = prediction_gateway
        end

        def fetch_primary_weather_payload(context:, display_start_date: nil, display_end_date: nil)
          if context.plan_predicted_weather_present
            @logger.info "✅ [FieldCultivationClimateWeatherActiveRecordGateway] Using saved prediction for CultivationPlan##{context.plan_id}, merging with observed data"
            weather_payload = merge_with_observed_data(
              context.predicted_weather_data,
              context,
              display_start_date,
              display_end_date
            )
          else
            @logger.warn "⚠️ [FieldCultivationClimateWeatherActiveRecordGateway] No cached prediction for CultivationPlan##{context.plan_id}, generating"
            plan = ::CultivationPlan.find(context.plan_id)
            farm = plan.farm
            service = @weather_prediction_service_factory.call(farm.weather_location, farm)
            prediction_info = service.predict_for_cultivation_plan(
              plan_weather: cultivation_plan_weather_snapshot(context)
            )
            weather_payload = prediction_info[:data]
          end

          ensure_weather_payload!(context.plan_id, weather_payload)
          weather_payload
        end

        def fetch_fallback_weather_payload(context:, display_start_date: nil, display_end_date: nil)
          plan = ::CultivationPlan.find(context.plan_id)
          farm = plan.farm
          weather_location = farm.weather_location

          fallback_get_weather_data_for_period(
            weather_location,
            context.start_date,
            context.completion_date,
            context.farm_latitude,
            context.farm_longitude,
            display_start_date,
            display_end_date
          )
        end

        def persist_predicted_weather_if_absent(plan_id:, weather_payload:)
          plan = ::CultivationPlan.find(plan_id)
          return if Domain::Shared::ValidationHelpers.present?(plan.predicted_weather_data)

          @cultivation_plan_gateway.update_predicted_weather_data(plan.id, weather_payload)
          @logger.info "💾 [FieldCultivationClimateWeatherActiveRecordGateway] Saved prediction data to CultivationPlan##{plan.id}"
        end

        private

        def ensure_weather_payload!(plan_id, weather_payload)
          return if weather_payload && weather_payload["data"]

          @logger.error "❌ [FieldCultivationClimateWeatherActiveRecordGateway] Invalid weather payload for CultivationPlan##{plan_id}"
          raise Domain::FieldCultivation::Errors::WeatherPayloadInvalidError,
                @translator.t("controllers.field_cultivations.errors.weather_format_invalid")
        end

        def merge_with_observed_data(cached_weather_payload, context, display_start_date, display_end_date)
          plan = ::CultivationPlan.find(context.plan_id)
          weather_location = plan.farm.weather_location
          display_start_date = coerce_to_optional_date(display_start_date)
          display_end_date = coerce_to_optional_date(display_end_date)

          if display_start_date && display_end_date
            observed_start = display_start_date
            observed_end = display_end_date
          else
            observed_start = coerce_to_optional_date(context.start_date)
            observed_end = coerce_to_optional_date(context.completion_date)
          end

          if observed_start.nil? || observed_end.nil?
            @logger.warn "🔄 [FieldCultivationClimateWeatherActiveRecordGateway] Skip observed merge: invalid observed range"
            return cached_weather_payload
          end

          actual_end = [ observed_end, Date.current - 1.day ].min

          if observed_start > actual_end
            @logger.info "🔄 [FieldCultivationClimateWeatherActiveRecordGateway] No observed data needed for period #{observed_start} to #{observed_end}"
            return cached_weather_payload
          end

          observed_weather_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: weather_location.id,
            start_date: observed_start,
            end_date: actual_end
          )

          return cached_weather_payload if observed_weather_data.empty?

          observed_formatted = {
            "latitude" => weather_location.latitude,
            "longitude" => weather_location.longitude,
            "elevation" => weather_location.elevation,
            "timezone" => weather_location.timezone,
            "data" => observed_weather_data.filter_map do |datum|
              next if datum.temperature_max.nil? || datum.temperature_min.nil?

              temp_mean = datum.temperature_mean || (datum.temperature_max + datum.temperature_min) / 2.0

              {
                "time" => datum.date.to_s,
                "temperature_2m_max" => datum.temperature_max.to_f,
                "temperature_2m_min" => datum.temperature_min.to_f,
                "temperature_2m_mean" => temp_mean.to_f,
                "precipitation_sum" => (datum.precipitation || 0.0).to_f,
                "sunshine_duration" => datum.sunshine_hours ? (datum.sunshine_hours.to_f * 3600.0) : 0.0,
                "wind_speed_10m_max" => (datum.wind_speed || 0.0).to_f,
                "weather_code" => datum.weather_code || 0
              }
            end
          }

          cached_data = Array(cached_weather_payload["data"])
          observed_data = observed_formatted["data"]

          merged_data = {}
          cached_data.each { |datum| merged_data[datum["time"]] = datum }
          observed_data.each { |datum| merged_data[datum["time"]] = datum }

          sorted_data = merged_data.values.sort_by { |datum| Date.parse(datum["time"]) }

          @logger.info "🔄 [FieldCultivationClimateWeatherActiveRecordGateway] Merged #{observed_data.length} observed data points with cached prediction data"

          cached_weather_payload.merge("data" => sorted_data)
        end

        def fallback_get_weather_data_for_period(weather_location, start_date, end_date, latitude, longitude, display_start_date, display_end_date)
          training_start_date = Date.current - 20.years
          training_end_date = Date.current - 2.days
          training_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: weather_location.id,
            start_date: training_start_date,
            end_date: training_end_date
          )

          training_formatted = {
            "latitude" => latitude,
            "longitude" => longitude,
            "timezone" => weather_location.timezone || "Asia/Tokyo",
            "data" => training_data.filter_map do |datum|
              next if datum.temperature_max.nil? || datum.temperature_min.nil?
              temp_mean = datum.temperature_mean || (datum.temperature_max + datum.temperature_min) / 2.0
              {
                "time" => datum.date.to_s,
                "temperature_2m_max" => datum.temperature_max.to_f,
                "temperature_2m_min" => datum.temperature_min.to_f,
                "temperature_2m_mean" => temp_mean.to_f,
                "precipitation_sum" => (datum.precipitation || 0.0).to_f
              }
            end
          }

          prediction_days = (end_date - training_end_date).to_i

          if prediction_days > 0
            future = @prediction_gateway.predict(
              historical_data: training_formatted,
              days: prediction_days,
              model: "lightgbm"
            )

            observed_start = coerce_to_optional_date(display_start_date) || Date.new(Date.current.year, 1, 1)
            observed_end = coerce_to_optional_date(display_end_date) || training_end_date
            observed_end = [ observed_end, Date.current - 1.day ].min

            current_year_data = @weather_data_gateway.weather_data_for_period(
              weather_location_id: weather_location.id,
              start_date: observed_start,
              end_date: observed_end
            )

            current_year_formatted = {
              "latitude" => latitude,
              "longitude" => longitude,
              "timezone" => weather_location.timezone || "Asia/Tokyo",
              "data" => current_year_data.filter_map do |datum|
                next if datum.temperature_max.nil? || datum.temperature_min.nil?
                temp_mean = datum.temperature_mean || (datum.temperature_max + datum.temperature_min) / 2.0
                {
                  "time" => datum.date.to_s,
                  "temperature_2m_max" => datum.temperature_max,
                  "temperature_2m_min" => datum.temperature_min,
                  "temperature_2m_mean" => temp_mean,
                  "precipitation_sum" => datum.precipitation || 0.0
                }
              end
            }

            merged_data = current_year_formatted["data"] + Domain::Shared::ValidationHelpers.to_array(future["data"])

            {
              "latitude" => latitude,
              "longitude" => longitude,
              "timezone" => weather_location.timezone || "Asia/Tokyo",
              "data" => merged_data
            }
          else
            @weather_data_gateway.format_for_agrr(
              weather_data_dtos: @weather_data_gateway.weather_data_for_period(
                weather_location_id: weather_location.id,
                start_date: start_date,
                end_date: end_date
              ),
              weather_location: weather_location
            )
          end
        end

        def cultivation_plan_weather_snapshot(context)
          Domain::WeatherData::Dtos::CultivationPlanWeather.new(
            id: context.plan_id,
            prediction_target_end_date: context.prediction_target_end_date,
            calculated_planning_end_date: context.calculated_planning_end_date,
            predicted_weather_data: context.predicted_weather_data
          )
        end

        def coerce_to_optional_date(value)
          return nil if value.nil?
          return nil if value.respond_to?(:empty?) && value.empty?
          return value if value.is_a?(Date)

          if value.respond_to?(:to_date)
            value.to_date
          else
            Date.parse(value.to_s)
          end
        rescue ArgumentError, TypeError, NoMethodError, Date::Error
          nil
        end
      end
    end
  end
end
