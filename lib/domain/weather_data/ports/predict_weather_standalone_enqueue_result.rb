# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      PredictWeatherStandaloneEnqueueResult = Struct.new(:ok, :error_message, keyword_init: true) do
        def self.success
          new(ok: true, error_message: nil)
        end

        def self.failure(message)
          new(ok: false, error_message: message)
        end
      end
    end
  end
end
