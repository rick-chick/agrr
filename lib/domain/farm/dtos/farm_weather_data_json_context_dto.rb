# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # JSON 天気 API 用にゲートウェイが一度だけ組み立てる農場コンテキスト（AR を境界に閉じる）。
      class FarmWeatherDataJsonContextDto
        attr_reader :farm_id, :display_name, :latitude, :longitude, :weather_location_id, :predicted_weather_data

        def initialize(farm_id:, display_name:, latitude:, longitude:, weather_location_id:, predicted_weather_data:)
          @farm_id = farm_id
          @display_name = display_name
          @latitude = latitude
          @longitude = longitude
          @weather_location_id = weather_location_id
          @predicted_weather_data = predicted_weather_data
        end
      end
    end
  end
end
