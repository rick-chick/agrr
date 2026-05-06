# frozen_string_literal: true

module Domain
  module WeatherData
    module Policies
      # 予測日数: `end_date` から「翌年12月31日」までの暦日数
      class WeatherPredictionHorizonPolicy
        def self.predict_days_to_next_year_end(end_date:, clock:)
          today = clock.today
          next_year_end = Date.new(today.year + 1, 12, 31)
          (next_year_end - end_date).to_i
        end
      end
    end
  end
end
