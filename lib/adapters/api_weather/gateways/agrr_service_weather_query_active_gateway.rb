# frozen_string_literal: true

module Adapters
  module ApiWeather
    module Gateways
      class AgrrServiceWeatherQueryActiveGateway < Domain::ApiWeather::Gateways::AgrrServiceWeatherQueryGateway
        def initialize(agrr_service:)
          @agrr_service = agrr_service
        end

        def fetch_historical_weather_data(location:, start_date:, end_date:, days:, data_source:)
          raw = @agrr_service.weather(
            location: location,
            start_date: start_date,
            end_date: end_date,
            days: days&.to_i,
            data_source: data_source,
            json: true
          )
          JSON.parse(raw)
        rescue JSON::ParserError
          raise Domain::ApiWeather::Errors::InvalidJsonResponse
        rescue ::Agrr::DaemonClient::DaemonNotRunningError
          raise Domain::ApiWeather::Errors::DaemonUnavailable
        rescue ::Agrr::DaemonClient::CommandExecutionError => e
          raise Domain::ApiWeather::Errors::CommandFailed, e.message
        end

        def fetch_forecast_weather_data(location:)
          raw = @agrr_service.forecast(location: location, json: true)
          JSON.parse(raw)
        rescue JSON::ParserError
          raise Domain::ApiWeather::Errors::InvalidJsonResponse
        rescue ::Agrr::DaemonClient::DaemonNotRunningError
          raise Domain::ApiWeather::Errors::DaemonUnavailable
        rescue ::Agrr::DaemonClient::CommandExecutionError => e
          raise Domain::ApiWeather::Errors::CommandFailed, e.message
        end

        def daemon_running?
          @agrr_service.daemon_running?
        end
      end
    end
  end
end
