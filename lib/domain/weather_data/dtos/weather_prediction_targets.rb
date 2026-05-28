# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # WeatherPredictionInteractor への入力（weather_location / farm の DTO ペア）。
      class WeatherPredictionTargets
        attr_reader :weather_location, :farm

        # @param weather_location [Domain::WeatherData::Contracts::WeatherLocationPredictionInput, nil]
        # @param farm [Domain::WeatherData::Contracts::FarmWeatherPredictionInput, nil]
        def initialize(weather_location:, farm:)
          @weather_location = weather_location
          @farm = farm
          freeze
        end
      end
    end
  end
end
