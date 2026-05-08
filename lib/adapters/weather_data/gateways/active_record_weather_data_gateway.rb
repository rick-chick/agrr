# frozen_string_literal: true

module Adapters
  module WeatherData
    module Gateways
      class ActiveRecordWeatherDataGateway
        include Domain::WeatherData::Gateways::WeatherDataGateway

        def weather_data_for_period(weather_location_id:, start_date: nil, end_date: nil)
          scope = WeatherDatum.where(weather_location_id: weather_location_id)
          scope = scope.where(date: start_date..end_date) if start_date && end_date
          scope = scope.where("date >= ?", start_date) if start_date && !end_date
          scope = scope.where("date <= ?", end_date) if end_date && !start_date
          scope.order(:date).map { |record| record.to_dto }
        end

        def format_for_agrr(weather_data_dtos:, weather_location:)
          wl = weather_location
          Domain::WeatherData::Services::OpenMeteoWeatherPayload.format_for_agrr(
            weather_data_dtos: weather_data_dtos,
            latitude: wl.latitude,
            longitude: wl.longitude,
            elevation: wl.elevation,
            timezone: wl.timezone
          )
        end

        def weather_data_count(weather_location_id:, start_date: nil, end_date: nil)
          scope = WeatherDatum.where(weather_location_id: weather_location_id)
          scope = scope.where(date: start_date..end_date) if start_date && end_date
          scope = scope.where("date >= ?", start_date) if start_date && !end_date
          scope = scope.where("date <= ?", end_date) if end_date && !start_date
          scope.count
        end

        def historical_data_count(weather_location_id:, start_date:, end_date:)
          scope = WeatherDatum.where(weather_location_id: weather_location_id, date: start_date..end_date)
          scope.where.not(temperature_max: nil, temperature_min: nil).count
        end

        def upsert_weather_data!(weather_data_dtos:, weather_location_id:)
          WeatherDatum.upsert_all(
            weather_data_dtos.map do |dto|
              {
                weather_location_id: weather_location_id,
                date: dto.date,
                temperature_max: dto.temperature_max,
                temperature_min: dto.temperature_min,
                temperature_mean: dto.temperature_mean,
                precipitation: dto.precipitation,
                sunshine_hours: dto.sunshine_hours,
                wind_speed: dto.wind_speed,
                weather_code: dto.weather_code,
                updated_at: Time.current
              }
            end,
            unique_by: [ :weather_location_id, :date ],
            update_only: [ :temperature_max, :temperature_min, :temperature_mean, :precipitation, :sunshine_hours, :wind_speed, :weather_code, :updated_at ]
          )
        end

        def total_weather_data_count
          WeatherDatum.count
        end

        def earliest_date(weather_location_id:)
          WeatherDatum.where(weather_location_id: weather_location_id).minimum(:date)
        end

        def latest_date(weather_location_id:)
          WeatherDatum.where(weather_location_id: weather_location_id).maximum(:date)
        end

        # @return [Domain::WeatherData::Dtos::WeatherLocationDto, nil]
        def find_weather_location_by_coordinates(latitude:, longitude:)
          loc = ::WeatherLocation.find_by(latitude: latitude, longitude: longitude)
          Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(loc)
        end

        # @return [Domain::WeatherData::Dtos::WeatherLocationDto]
        def find_or_create_weather_location(latitude:, longitude:, elevation: nil, timezone: nil)
          loc = ::WeatherLocation.find_or_create_by(
            latitude: latitude,
            longitude: longitude
          ) do |location|
            location.elevation = elevation
            location.timezone = timezone
          end
          Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(loc)
        end

        def update_predicted_weather_data(weather_location_id:, payload:)
          wl = ::WeatherLocation.find(weather_location_id)
          wl.timezone ||= "UTC"
          wl.update!(predicted_weather_data: payload)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end
      end
    end
  end
end
