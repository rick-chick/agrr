# frozen_string_literal: true

module Domain
  module WeatherData
    module InputPorts
      module FetchWeatherDataDiscardOnInputPort
        def call(input_dto:)
          raise NotImplementedError, "Subclasses must implement call(input_dto:) for discard_on logic"
        end
      end
    end
  end
end
