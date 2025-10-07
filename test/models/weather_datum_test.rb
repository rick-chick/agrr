# frozen_string_literal: true

require "test_helper"

class WeatherDatumTest < ActiveSupport::TestCase
  setup do
    @location = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: "Asia/Tokyo"
    )
  end

  test "valid weather datum" do
    datum = WeatherDatum.new(
      weather_location: @location,
      date: Date.today,
      temperature_max: 25.5,
      temperature_min: 15.3,
      temperature_mean: 20.4,
      precipitation: 0.0,
      sunshine_hours: 8.5,
      wind_speed: 12.3,
      weather_code: 0
    )
    assert datum.valid?
  end

  test "requires weather_location" do
    datum = WeatherDatum.new(date: Date.today)
    assert_not datum.valid?
    assert_includes datum.errors[:weather_location], "must exist"
  end

  test "requires date" do
    datum = WeatherDatum.new(weather_location: @location)
    assert_not datum.valid?
    assert_includes datum.errors[:date], "can't be blank"
  end

  test "enforces unique date per location" do
    WeatherDatum.create!(
      weather_location: @location,
      date: Date.today
    )
    
    duplicate = WeatherDatum.new(
      weather_location: @location,
      date: Date.today
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:date], "has already been taken"
  end

  test "allows same date for different locations" do
    other_location = WeatherLocation.create!(
      latitude: 34.0,
      longitude: 135.0,
      timezone: "Asia/Tokyo"
    )
    
    WeatherDatum.create!(
      weather_location: @location,
      date: Date.today
    )
    
    datum = WeatherDatum.new(
      weather_location: other_location,
      date: Date.today
    )
    assert datum.valid?
  end

  test "temperature_range calculates correctly" do
    datum = WeatherDatum.create!(
      weather_location: @location,
      date: Date.today,
      temperature_max: 25.5,
      temperature_min: 15.3
    )
    assert_in_delta 10.2, datum.temperature_range, 0.01
  end

  test "temperature_range returns nil when data missing" do
    datum = WeatherDatum.create!(
      weather_location: @location,
      date: Date.today
    )
    assert_nil datum.temperature_range
  end

  test "has_precipitation? returns true when precipitation exists" do
    datum = WeatherDatum.create!(
      weather_location: @location,
      date: Date.today,
      precipitation: 5.0
    )
    assert datum.has_precipitation?
  end

  test "has_precipitation? returns false when no precipitation" do
    datum = WeatherDatum.create!(
      weather_location: @location,
      date: Date.today,
      precipitation: 0.0
    )
    assert_not datum.has_precipitation?
  end
end

