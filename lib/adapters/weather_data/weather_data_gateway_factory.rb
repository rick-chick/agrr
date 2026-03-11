# frozen_string_literal: true

module Adapters
  module WeatherData
    class WeatherDataGatewayFactory
      STORAGE_ACTIVE_RECORD = "active_record"
      STORAGE_GCS = "gcs"

      def self.resolve
        case ENV.fetch("WEATHER_DATA_STORAGE", STORAGE_ACTIVE_RECORD)
        when STORAGE_GCS
          Adapters::WeatherData::Gateways::GcsWeatherDataGateway.new
        else
          Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
        end
      end
    end
  end
end
