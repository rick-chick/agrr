# frozen_string_literal: true

module Domain
  module WeatherData
    module Policies
      # Ruby: `UpdateReferenceWeatherDataJob` date range (not `WeatherDataFetchWindowPolicy`).
      class SchedulerReferenceFarmFetchWindowPolicy
        WEATHER_DATA_LOOKBACK_DAYS = 7

        def self.fetch_range(clock:)
          today = clock.today
          start_date = today - WEATHER_DATA_LOOKBACK_DAYS
          end_date = today
          return nil if start_date > end_date

          { start_date: start_date, end_date: end_date }
        end
      end
    end
  end
end
