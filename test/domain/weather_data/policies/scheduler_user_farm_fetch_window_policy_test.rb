# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Policies
      class SchedulerUserFarmFetchWindowPolicyTest < DomainLibTestCase
        FakeClock = Struct.new(:today)

        test "uses latest plus one through today" do
          clock = FakeClock.new(Date.new(2026, 6, 15))
          latest = Date.new(2026, 6, 10)

          range = SchedulerUserFarmFetchWindowPolicy.fetch_range(latest_weather_date: latest, clock: clock)

          assert_equal Date.new(2026, 6, 11), range[:start_date]
          assert_equal Date.new(2026, 6, 15), range[:end_date]
        end

        test "without latest uses seven day lookback" do
          clock = FakeClock.new(Date.new(2026, 6, 15))

          range = SchedulerUserFarmFetchWindowPolicy.fetch_range(latest_weather_date: nil, clock: clock)

          assert_equal Date.new(2026, 6, 8), range[:start_date]
          assert_equal Date.new(2026, 6, 15), range[:end_date]
        end

        test "skips when already up to date" do
          clock = FakeClock.new(Date.new(2026, 6, 15))

          assert_nil SchedulerUserFarmFetchWindowPolicy.fetch_range(
            latest_weather_date: Date.new(2026, 6, 15),
            clock: clock
          )
        end
      end
    end
  end
end
