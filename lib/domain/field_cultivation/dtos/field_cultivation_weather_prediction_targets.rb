# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 計画天気予測の入力対象（WeatherPredictionInteractor 用）。
      class FieldCultivationWeatherPredictionTargets
        attr_reader :weather_location, :farm

        def initialize(weather_location:, farm:)
          @weather_location = weather_location
          @farm = farm
          freeze
        end
      end
    end
  end
end
