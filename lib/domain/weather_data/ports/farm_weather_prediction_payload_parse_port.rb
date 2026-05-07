# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      module FarmWeatherPredictionPayloadParsePort
        # @return [Time, nil]
        def predicted_at_from_payload(iso8601_string)
          raise NotImplementedError, "#{self.class} must implement predicted_at_from_payload"
        end

        # @return [Date, nil]
        def prediction_start_date_from_payload(string)
          raise NotImplementedError, "#{self.class} must implement prediction_start_date_from_payload"
        end
      end
    end
  end
end
