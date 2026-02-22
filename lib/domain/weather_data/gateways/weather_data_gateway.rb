# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      module WeatherDataGateway

        def total_weather_data_count
          raise NotImplementedError
        end

        def weather_data_for_period(weather_location_id:, start_date: nil, end_date: nil)
          raise NotImplementedError
        end

        def normalize_weather_data(raw_data:)
          raise NotImplementedError
        end

        def extract_weather_data_by_period(raw_weather_payload:, start_date:, end_date:)
          raise NotImplementedError
        end

        def format_for_agrr(weather_data_dtos:, weather_location:)
          raise NotImplementedError
        end

        def weather_data_count(weather_location_id:, start_date: nil, end_date: nil)
          raise NotImplementedError
        end

        def earliest_date(weather_location_id:)
          raise NotImplementedError
        end

        def latest_date(weather_location_id:)
          raise NotImplementedError
        end

        def upsert_weather_data!(weather_data_dtos:, weather_location_id:)
          raise NotImplementedError
        end

        # 新規追加: WeatherLocation 検索
        def find_weather_location_by_coordinates(latitude:, longitude:)
          raise NotImplementedError, "Subclasses must implement find_weather_location_by_coordinates"
        end

        # 新規追加: WeatherLocation 検索/作成
        def find_or_create_weather_location(latitude:, longitude:, elevation: nil, timezone: nil)
          raise NotImplementedError, "Subclasses must implement find_or_create_weather_location"
        end
      end
    end
  end
end
