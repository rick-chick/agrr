# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # WeatherLocation の永続化表現をドメイン境界で受け渡す。
      class WeatherLocation
        include Domain::WeatherData::Contracts::WeatherLocationPredictionInput

        attr_reader :id, :latitude, :longitude, :elevation, :timezone, :predicted_weather_data

        def initialize(id:, latitude:, longitude:, elevation: nil, timezone: nil, predicted_weather_data: nil)
          @id = id
          @latitude = latitude
          @longitude = longitude
          @elevation = elevation
          @timezone = timezone
          @predicted_weather_data = Domain::WeatherData::PayloadImmutable.copy_and_deep_freeze(predicted_weather_data)
          freeze
        end
      end
    end
  end
end
