# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # 天気予測インターラクタ用: Farm のキャッシュ参照のみ（AR 非依存）。
      class FarmWeatherPrediction
        include Domain::WeatherData::Contracts::FarmWeatherPredictionInput

        attr_reader :id, :weather_location_id, :predicted_weather_data

        def initialize(id:, weather_location_id:, predicted_weather_data: nil)
          @id = id
          @weather_location_id = weather_location_id
          @predicted_weather_data = Domain::WeatherData::PayloadImmutable.copy_and_deep_freeze(predicted_weather_data)
          freeze
        end
      end
    end
  end
end
