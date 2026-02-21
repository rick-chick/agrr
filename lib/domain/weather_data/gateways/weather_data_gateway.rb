# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      module WeatherDataGateway
        def weather_data_for_period(weather_location_id:, start_date:, end_date:)
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
      end
    end
  end
end
