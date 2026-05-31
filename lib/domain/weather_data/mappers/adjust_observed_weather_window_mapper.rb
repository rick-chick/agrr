# frozen_string_literal: true

module Domain
  module WeatherData
    module Mappers
      # adjust 時の観測取得窓（WeatherPrediction の当年履歴と同様に当年 1/1 を含める）。
      module AdjustObservedWeatherWindowMapper
        module_function

        # @return [Hash] :start_date, :end_date
        def historical_fetch_window(effective_planning_start:, today:)
          current_year_start = Date.new(today.year, 1, 1)
          {
            start_date: [ effective_planning_start, current_year_start ].min,
            end_date: today - 1
          }
        end
      end
    end
  end
end
