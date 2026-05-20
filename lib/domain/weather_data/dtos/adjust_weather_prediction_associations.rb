# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # adjust_with_db_weather から WeatherPredictionInteractor を組み立てる際の連想（AR 非依存）。
      class AdjustWeatherPredictionAssociations
        attr_reader :weather_location, :farm

        # @param weather_location [Domain::WeatherData::Dtos::WeatherLocation, nil]
        # @param farm [Domain::WeatherData::Dtos::FarmWeatherPrediction, nil]
        def initialize(weather_location:, farm:)
          @weather_location = weather_location
          @farm = farm
          freeze
        end
      end
    end
  end
end
