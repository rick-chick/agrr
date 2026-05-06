# frozen_string_literal: true

require "test_helper"

class WeatherDataPeriodPoliciesTest < ActiveSupport::TestCase
  FakeClock = Struct.new(:today)

  test "fetch_range uses latest_weather_date and minimum today-2" do
    clock = FakeClock.new(Date.new(2026, 6, 15))
    latest = Date.new(2025, 1, 1)
    r = Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
      latest_weather_date: latest,
      clock: clock
    )
    assert_equal Date.new(2006, 6, 15), r[:start_date]
    assert_equal Date.new(2026, 6, 13), r[:end_date]
    assert_not r[:range_adjusted]
  end

  test "fetch_range never returns start_date after end_date" do
    clock = FakeClock.new(Date.new(2026, 8, 20))
    r = Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
      latest_weather_date: Date.new(1900, 1, 1),
      clock: clock
    )
    assert_operator r[:start_date], :<=, r[:end_date]
    assert_equal false, r[:range_adjusted]
  end

  test "predict_days_to_next_year_end counts days to Dec 31 next calendar year" do
    clock = FakeClock.new(Date.new(2026, 5, 6))
    end_date = Date.new(2026, 5, 1)
    days = Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy.predict_days_to_next_year_end(
      end_date: end_date,
      clock: clock
    )
    assert_equal (Date.new(2027, 12, 31) - end_date).to_i, days
  end
end
