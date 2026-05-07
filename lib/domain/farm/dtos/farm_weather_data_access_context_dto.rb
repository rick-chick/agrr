# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # 農場天気参照用にゲートウェイが一度だけ組み立てる読み取りスナップショット（AR を境界に閉じる）。
      class FarmWeatherDataAccessContextDto
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
