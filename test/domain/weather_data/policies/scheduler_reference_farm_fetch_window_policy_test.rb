# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Policies
      class SchedulerReferenceFarmFetchWindowPolicyTest < DomainLibTestCase
        FakeClock = Struct.new(:today)

        test "fetch_range is today minus 7 through today" do
          clock = FakeClock.new(Date.new(2026, 5, 1))

          range = SchedulerReferenceFarmFetchWindowPolicy.fetch_range(clock: clock)

          assert_equal Date.new(2026, 4, 24), range[:start_date]
          assert_equal Date.new(2026, 5, 1), range[:end_date]
        end
      end
    end
  end
end
