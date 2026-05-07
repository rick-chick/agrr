# frozen_string_literal: true

module Adapters
  module WeatherData
    class FarmWeatherPredictionPayloadParseAdapter
      include Domain::WeatherData::Ports::FarmWeatherPredictionPayloadParsePort

      def predicted_at_from_payload(iso8601_string)
        Adapters::Shared::Iso8601TimeParse.parse_in_application_zone(iso8601_string)
      end

      def prediction_start_date_from_payload(string)
        Adapters::Shared::Iso8601CalendarDate.parse(string)
      end
    end
  end
end
