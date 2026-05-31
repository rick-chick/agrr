# frozen_string_literal: true

module Domain
  module WeatherData
    module Policies
      # Ruby: `UpdateUserFarmsWeatherDataJob` per-farm window.
      class SchedulerUserFarmFetchWindowPolicy
        DEFAULT_LOOKBACK_DAYS = 7

        def self.fetch_range(latest_weather_date:, clock:)
          today = clock.today
          start_date = if latest_weather_date
                         latest_weather_date + 1
                       else
                         today - DEFAULT_LOOKBACK_DAYS
                       end

          return nil if start_date > today

          end_date = today
          return nil if start_date > end_date

          { start_date: start_date, end_date: end_date }
        end
      end
    end
  end
end
