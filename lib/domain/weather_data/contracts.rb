# frozen_string_literal: true

module Domain
  module WeatherData
    module Contracts
      # 天気予測インターラクタへの入力マーカー（具象 DTO のほか、テストスタブが include できる）
      module WeatherLocationPredictionInput
      end

      module FarmWeatherPredictionInput
      end

      module CultivationPlanWeatherPredictionInput
      end
    end
  end
end
