# frozen_string_literal: true

module Domain
  module ApiWeather
    module Interactors
      class ApiWeatherHistoricalInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(location:, start_date:, end_date:, days:, data_source:)
          if location.blank?
            fdto = Domain::ApiWeather::Dtos::ApiWeatherFailure
            @output_port.on_failure(fdto.new(fdto::KIND_LOCATION_REQUIRED))
            return
          end

          data = @gateway.fetch_historical_weather_data(
            location: location,
            start_date: start_date,
            end_date: end_date,
            days: days,
            data_source: data_source
          )
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
