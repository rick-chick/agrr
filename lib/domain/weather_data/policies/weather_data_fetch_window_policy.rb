# frozen_string_literal: true

module Domain
  module WeatherData
    module Policies
      # 気象データ取得レンジ（開始・終了日）。時刻は `clock.today` のみ参照する。
      class WeatherDataFetchWindowPolicy
        # @param latest_weather_date [Date, nil]
        # @param clock [#today] エッジから注入（例: ActiveSupport::TimeZone）
        def self.fetch_range(latest_weather_date:, clock:)
          today = clock.today
          start_date = today << (12 * 20)
          minimum_end = today - 2
          end_date = [ latest_weather_date, minimum_end ].compact.max

          adjusted = false
          if start_date > end_date
            adjusted = true
            end_date = start_date + 1
          end

          { start_date: start_date, end_date: end_date, range_adjusted: adjusted }
        end
      end
    end
  end
end
