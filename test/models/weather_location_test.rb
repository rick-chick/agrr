# frozen_string_literal: true

require "test_helper"

class WeatherLocationTest < ActiveSupport::TestCase
  test "valid weather location" do
    location = WeatherLocation.new(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 40.0,
      timezone: "Asia/Tokyo"
    )
    assert location.valid?
  end

  test "requires latitude" do
    location = WeatherLocation.new(longitude: 139.6503, timezone: "Asia/Tokyo")
    assert_not location.valid?
    assert_includes location.errors[:latitude], "can't be blank"
  end

  test "requires longitude" do
    location = WeatherLocation.new(latitude: 35.6762, timezone: "Asia/Tokyo")
    assert_not location.valid?
    assert_includes location.errors[:longitude], "can't be blank"
  end

  test "requires timezone" do
    location = WeatherLocation.new(latitude: 35.6762, longitude: 139.6503)
    assert_not location.valid?
    assert_includes location.errors[:timezone], "can't be blank"
  end

  test "validates latitude range" do
    location = WeatherLocation.new(latitude: 91, longitude: 139.6503, timezone: "Asia/Tokyo")
    assert_not location.valid?
    assert_includes location.errors[:latitude], "must be less than or equal to 90"

    location.latitude = -91
    assert_not location.valid?
    assert_includes location.errors[:latitude], "must be greater than or equal to -90"
  end

  test "validates longitude range" do
    location = WeatherLocation.new(latitude: 35.6762, longitude: 181, timezone: "Asia/Tokyo")
    assert_not location.valid?
    assert_includes location.errors[:longitude], "must be less than or equal to 180"

    location.longitude = -181
    assert_not location.valid?
    assert_includes location.errors[:longitude], "must be greater than or equal to -180"
  end

  test "enforces unique coordinates" do
    WeatherLocation.create!(latitude: 35.6762, longitude: 139.6503, timezone: "Asia/Tokyo")
    duplicate = WeatherLocation.new(latitude: 35.6762, longitude: 139.6503, timezone: "Asia/Tokyo")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:latitude], "has already been taken"
  end

  test "find_or_create_by_coordinates creates new location" do
    location = WeatherLocation.find_or_create_by_coordinates(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 40.0,
      timezone: "Asia/Tokyo"
    )
    
    assert location.persisted?
    assert_equal 35.6762, location.latitude
    assert_equal 139.6503, location.longitude
    assert_equal 40.0, location.elevation
    assert_equal "Asia/Tokyo", location.timezone
  end

  test "find_or_create_by_coordinates finds existing location" do
    existing = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 40.0,
      timezone: "Asia/Tokyo"
    )
    
    location = WeatherLocation.find_or_create_by_coordinates(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 50.0,
      timezone: "UTC"
    )
    
    assert_equal existing.id, location.id
  end

  test "coordinates returns array" do
    location = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: "Asia/Tokyo"
    )
    assert_equal [35.6762, 139.6503], location.coordinates
  end

  test "coordinates_string returns formatted string" do
    location = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: "Asia/Tokyo"
    )
    assert_match /35\.6762,139\.6503/, location.coordinates_string
  end
end

