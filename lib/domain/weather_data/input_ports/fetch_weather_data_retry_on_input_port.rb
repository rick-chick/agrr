# frozen_string_literal: true

module Domain
  module WeatherData
    module InputPorts
      module FetchWeatherDataRetryOnInputPort
        def execute(input_dto:)
          raise NotImplementedError, "Subclasses must implement execute(input_dto:) for retry_on logic"
        end
      end
    end
  end
end
