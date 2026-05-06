# frozen_string_literal: true

module Domain
  module ApiWeather
    module Ports
      class ApiWeatherForecastOutputPort
        def on_success(forecast_json)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
