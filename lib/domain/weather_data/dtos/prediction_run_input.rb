# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # agrr 予測APIへの入力（履歴ペイロードはハッシュ／配列でアダプターがdaemonへ渡す）。
      class PredictionRunInput
        attr_reader :historical_data, :days, :model

        def initialize(historical_data:, days:, model: "lightgbm")
          @historical_data = historical_data
          @days = days
          @model = model
        end
      end
    end
  end
end
