# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # 天気予測インターラクタ用: 栽培計画の予測対象日・キャッシュ（AR 非依存）。
      class CultivationPlanWeatherDto
        include Domain::WeatherData::Contracts::CultivationPlanWeatherPredictionInput

        attr_reader :id, :prediction_target_end_date, :calculated_planning_end_date, :predicted_weather_data

        def initialize(id:, prediction_target_end_date: nil, calculated_planning_end_date: nil, predicted_weather_data: nil)
          @id = id
          @prediction_target_end_date = prediction_target_end_date
          @calculated_planning_end_date = calculated_planning_end_date
          @predicted_weather_data = Domain::WeatherData::PayloadImmutable.copy_and_deep_freeze(predicted_weather_data)
          freeze
        end
      end
    end
  end
end
