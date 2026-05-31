# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module WeatherData
    module Mappers
      class AdjustObservedWeatherWindowMapperTest < DomainLibTestCase
        test "historical fetch window includes current-year start when planning starts mid-year" do
          window = AdjustObservedWeatherWindowMapper.historical_fetch_window(
            effective_planning_start: Date.new(2026, 3, 1),
            today: Date.new(2026, 5, 31)
          )

          assert_equal Date.new(2026, 1, 1), window[:start_date]
          assert_equal Date.new(2026, 5, 30), window[:end_date]
        end

        test "historical fetch window keeps earlier planning start across year boundary" do
          window = AdjustObservedWeatherWindowMapper.historical_fetch_window(
            effective_planning_start: Date.new(2025, 6, 1),
            today: Date.new(2026, 5, 31)
          )

          assert_equal Date.new(2025, 6, 1), window[:start_date]
          assert_equal Date.new(2026, 5, 30), window[:end_date]
        end
      end
    end
  end
end
