# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationClimateWeatherPayloadMapper
        module_function

        def coerce_optional_date(value)
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

        # @param observed_weather_dtos [Array] adapter 由来の日次 DTO（temperature_max/min 等）
        # @param weather_location_meta [Hash] :latitude, :longitude, :elevation, :timezone
        def build_observed_agrr_payload(weather_location_meta:, observed_weather_dtos:)
          {
            "latitude" => weather_location_meta[:latitude],
            "longitude" => weather_location_meta[:longitude],
            "elevation" => weather_location_meta[:elevation],
            "timezone" => weather_location_meta[:timezone],
            "data" => Array(observed_weather_dtos).filter_map do |datum|
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
        end

        def build_observed_agrr_payload_simple(weather_location_meta:, observed_weather_dtos:)
          {
            "latitude" => weather_location_meta[:latitude],
            "longitude" => weather_location_meta[:longitude],
            "timezone" => weather_location_meta[:timezone],
            "data" => Array(observed_weather_dtos).filter_map do |datum|
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
        end

        # @param cached_weather_payload [Hash]
        # @param observed_formatted [Hash] build_observed_agrr_payload 結果
        def merge_cached_with_observed(cached_weather_payload:, observed_formatted:)
          cached_data = Array(cached_weather_payload["data"])
          observed_data = Array(observed_formatted["data"])
          return cached_weather_payload if observed_data.empty?

          merged_data = {}
          cached_data.each { |datum| merged_data[datum["time"]] = datum }
          observed_data.each { |datum| merged_data[datum["time"]] = datum }

          sorted_data = merged_data.values.sort_by { |datum| Date.parse(datum["time"]) }
          cached_weather_payload.merge("data" => sorted_data)
        end

        def merge_training_and_future(training_formatted:, future_payload:)
          merged_data = Array(training_formatted["data"]) + Domain::Shared::ValidationHelpers.to_array(future_payload["data"])
          {
            "latitude" => training_formatted["latitude"],
            "longitude" => training_formatted["longitude"],
            "timezone" => training_formatted["timezone"],
            "data" => merged_data
          }
        end

        def valid_weather_payload?(weather_payload)
          weather_payload && weather_payload["data"]
        end

        # @param source [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        def weather_location_meta_from_source(source:)
          {
            latitude: source.farm_latitude,
            longitude: source.farm_longitude,
            elevation: nil,
            timezone: source.weather_location_timezone || "Asia/Tokyo"
          }
        end
      end
    end
  end
end
