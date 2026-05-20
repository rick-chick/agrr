# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # 天気予測 Interactor が参照日に基づき使う日付境界（Rails の期間計算はアダプタ側）。
      class WeatherPredictionAnchors
        attr_reader :training_start_date,
                    :training_end_date,
                    :current_year_history_start_date,
                    :current_year_history_end_date,
                    :default_target_end_date

        def initialize(
          training_start_date:,
          training_end_date:,
          current_year_history_start_date:,
          current_year_history_end_date:,
          default_target_end_date:
        )
          @training_start_date = training_start_date
          @training_end_date = training_end_date
          @current_year_history_start_date = current_year_history_start_date
          @current_year_history_end_date = current_year_history_end_date
          @default_target_end_date = default_target_end_date
        end
      end
    end
  end
end
