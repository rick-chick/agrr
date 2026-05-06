# frozen_string_literal: true

module Domain
  module ApiWeather
    module Ports
      class ApiWeatherHistoricalOutputPort
        def on_success(weather_json)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
