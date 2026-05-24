# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Farm::Calculators::FarmWeatherProgressCalculatorTest < DomainLibTestCase
  Calc = Domain::Farm::Calculators::FarmWeatherProgressCalculator

  test "progress_percent returns 0 when total is zero" do
    assert_equal 0, Calc.progress_percent(fetched: 0, total: 0)
  end

  test "next_after_block increments fetched and completes at total" do
    attrs, = Calc.next_after_block(
      fetched: 1,
      total: 2,
      last_broadcast_at: nil,
      current_time: Time.utc(2025, 1, 1, 12, 0, 0)
    )
    assert_equal 2, attrs[:weather_data_fetched_years]
    assert_equal "completed", attrs[:weather_data_status]
  end
end
