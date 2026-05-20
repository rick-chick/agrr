# frozen_string_literal: true

module Domain
  module WeatherData
    module InputPorts
      module FetchWeatherDataPerformInputPort
        def call(input_dto:)
          raise NotImplementedError, "Subclasses must implement call(input_dto:) for perform logic"
        end
      end
    end
  end
end
