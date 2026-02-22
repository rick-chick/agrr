# frozen_string_literal: true

module Adapters
  module WeatherData
    module Gateways
      class ActiveRecordWeatherDataGateway
        include Domain::WeatherData::Gateways::WeatherDataGateway

        def weather_data_for_period(weather_location_id:, start_date: nil, end_date: nil)
          scope = WeatherDatum.where(weather_location_id: weather_location_id)
          scope = scope.where(date: start_date..end_date) if start_date && end_date
          scope = scope.where('date >= ?', start_date) if start_date && !end_date
          scope = scope.where('date <= ?', end_date) if end_date && !start_date
          scope.order(:date).map { |record| record.to_dto }
        end

        def normalize_weather_data(raw_data:)
          AgrrService.normalize_weather_data(raw_data)
        end

        def extract_weather_data_by_period(raw_weather_payload:, start_date:, end_date:)
          return [] unless raw_weather_payload['data']

          raw_weather_payload['data'].filter_map do |datum|
            next unless datum['time']
            datum_date = Date.parse(datum['time']) rescue nil
            next unless datum_date&.between?(start_date, end_date)

            temp_mean = datum['temperature_2m_mean']
            temp_mean ||= (datum['temperature_2m_max'] + datum['temperature_2m_min']) / 2.0 if datum['temperature_2m_max'] && datum['temperature_2m_min']

            Domain::WeatherData::Dtos::WeatherDataDto.new(
              date: datum_date,
              temperature_max: datum['temperature_2m_max'],
              temperature_min: datum['temperature_2m_min'],
              temperature_mean: temp_mean,
              precipitation: datum['precipitation_sum'],
              sunshine_hours: datum['sunshine_duration'] ? datum['sunshine_duration'].to_f / 3600.0 : nil,
              wind_speed: datum['wind_speed_10m_max'],
              weather_code: datum['weather_code']
            )
          end
        end

        def format_for_agrr(weather_data_dtos:, weather_location:)
          {
            'latitude' => weather_location.latitude.to_f,
            'longitude' => weather_location.longitude.to_f,
            'elevation' => (weather_location.elevation || 0.0).to_f,
            'timezone' => weather_location.timezone,
            'data' => weather_data_dtos.map do |dto|
              {
                'time' => dto.date.to_s,
                'temperature_2m_max' => dto.temperature_max,
                'temperature_2m_min' => dto.temperature_min,
                'temperature_2m_mean' => dto.temperature_mean,
                'precipitation_sum' => dto.precipitation,
                'sunshine_duration' => dto.sunshine_hours ? dto.sunshine_hours.to_f * 3600.0 : 0.0,
                'wind_speed_10m_max' => dto.wind_speed,
                'weather_code' => dto.weather_code
              }
            end.compact
          }
        end

        def weather_data_count(weather_location_id:, start_date: nil, end_date: nil)
          scope = WeatherDatum.where(weather_location_id: weather_location_id)
          scope = scope.where(date: start_date..end_date) if start_date && end_date
          scope = scope.where('date >= ?', start_date) if start_date && !end_date
          scope = scope.where('date <= ?', end_date) if end_date && !start_date
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
            unique_by: [:weather_location_id, :date],
            update_only: [:temperature_max, :temperature_min, :temperature_mean, :precipitation, :sunshine_hours, :wind_speed, :weather_code, :updated_at]
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
      end
    end
  end
end
