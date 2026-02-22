# frozen_string_literal: true

module Domain
  module WeatherData
    module InputPorts
      module FetchWeatherDataPerformInputPort
        def execute(input_dto:)
          raise NotImplementedError, "Subclasses must implement execute(input_dto:) for perform logic"
        end
      end
    end
  end
end
