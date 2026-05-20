# frozen_string_literal: true

module Domain
  module ApiWeather
    module Interactors
      class ApiWeatherForecastInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(location:)
          if location.blank?
            fdto = Domain::ApiWeather::Dtos::ApiWeatherFailure
            @output_port.on_failure(fdto.new(fdto::KIND_LOCATION_REQUIRED))
            return
          end

          data = @gateway.fetch_forecast_weather_data(location: location)
          @output_port.on_success(data)
        rescue Domain::ApiWeather::Errors::InvalidJsonResponse
          fdto = Domain::ApiWeather::Dtos::ApiWeatherFailure
          @output_port.on_failure(fdto.new(fdto::KIND_INVALID_JSON))
        rescue Domain::ApiWeather::Errors::DaemonUnavailable
          fdto = Domain::ApiWeather::Dtos::ApiWeatherFailure
          @output_port.on_failure(fdto.new(fdto::KIND_DAEMON_UNAVAILABLE))
        rescue Domain::ApiWeather::Errors::CommandFailed => e
          fdto = Domain::ApiWeather::Dtos::ApiWeatherFailure
          @output_port.on_failure(fdto.new(fdto::KIND_COMMAND_FAILED, e.message))
        end
      end
    end
  end
end
