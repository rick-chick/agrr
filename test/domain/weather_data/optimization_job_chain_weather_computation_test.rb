# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::WeatherData::OptimizationJobChainWeatherComputationTest < DomainLibTestCase
  Mod = Domain::WeatherData::OptimizationJobChainWeatherComputation
  FakeClock = Struct.new(:today)

  test "weather_window delegates to WeatherDataFetchWindowPolicy" do
    clock = FakeClock.new(Date.new(2026, 6, 15))
    latest = Date.new(2025, 1, 1)
    expected = Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
      latest_weather_date: latest,
      clock: clock
    )

    assert_equal expected, Mod.weather_window(latest_weather_date: latest, clock: clock)
  end

  test "predict_days_to_next_year_end delegates to WeatherPredictionHorizonPolicy" do
    clock = FakeClock.new(Date.new(2026, 5, 6))
    end_date = Date.new(2026, 5, 1)
    expected = Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy.predict_days_to_next_year_end(
      end_date: end_date,
      clock: clock
    )

    assert_equal expected, Mod.predict_days_to_next_year_end(end_date: end_date, clock: clock)
  end
end
