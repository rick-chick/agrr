# frozen_string_literal: true

module Domain
  module ApiWeather
    module Gateways
      # agrr デーモン経由の生 JSON 天気照会（文字列 location）
      class AgrrServiceWeatherQueryGateway
        def fetch_historical_weather_data(location:, start_date:, end_date:, days:, data_source:)
          raise NotImplementedError, "Subclasses must implement fetch_historical_weather_data"
        end

        def fetch_forecast_weather_data(location:)
          raise NotImplementedError, "Subclasses must implement fetch_forecast_weather_data"
        end

        def daemon_running?
          raise NotImplementedError, "Subclasses must implement daemon_running?"
        end
      end
    end
  end
end
