# frozen_string_literal: true

require "test_helper"

class FetchWeatherDataJobTest < ActiveJob::TestCase
  setup do
    WeatherDatum.delete_all
    WeatherLocation.delete_all
  end

  test "creates weather location and data" do
    # Skip this test if not in Docker environment with agrr available
    skip "Test requires agrr command" unless File.exist?(Rails.root.join('lib', 'core', 'agrr'))

    assert_difference 'WeatherLocation.count', 1 do
      assert_difference 'WeatherDatum.count', 7 do
        FetchWeatherDataJob.perform_now(
          latitude: 35.6762,
          longitude: 139.6503,
          start_date: Date.new(2025, 9, 1),
          end_date: Date.new(2025, 9, 7)
        )
      end
    end

    location = WeatherLocation.last
    assert_not_nil location
    
    # Check that the location coordinates are from agrr (may be slightly different due to rounding)
    assert_in_delta 35.67, location.latitude, 0.1
    assert_in_delta 139.69, location.longitude, 0.1
    assert_equal "Asia/Tokyo", location.timezone

    # Check weather data
    weather_data = location.weather_data.order(:date)
    assert_equal 7, weather_data.count
    assert_equal Date.new(2025, 9, 1), weather_data.first.date
    assert_equal Date.new(2025, 9, 7), weather_data.last.date
  end

  test "uses existing weather location if coordinates already exist" do
    skip "Test requires agrr command" unless File.exist?(Rails.root.join('lib', 'core', 'agrr'))

    # First fetch
    FetchWeatherDataJob.perform_now(
      latitude: 35.6762,
      longitude: 139.6503,
      start_date: Date.new(2025, 9, 1),
      end_date: Date.new(2025, 9, 3)
    )

    initial_location = WeatherLocation.first
    assert_not_nil initial_location, "WeatherLocation should be created"
    assert_equal 3, initial_location.weather_data.count

    # Second fetch with same location, overlapping dates (1-3 existing, 4-7 new)
    assert_no_difference 'WeatherLocation.count' do
      # Total will be 7 (3 existing updated + 4 new created)
      FetchWeatherDataJob.perform_now(
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: Date.new(2025, 9, 1),
        end_date: Date.new(2025, 9, 7)
      )
    end

    # Should use the same location
    initial_location.reload
    assert_equal 1, WeatherLocation.count
    assert_equal 7, initial_location.weather_data.count
  end

  test "updates existing weather data" do
    skip "Test requires agrr command" unless File.exist?(Rails.root.join('lib', 'core', 'agrr'))

    # First fetch
    FetchWeatherDataJob.perform_now(
      latitude: 35.6762,
      longitude: 139.6503,
      start_date: Date.new(2025, 9, 1),
      end_date: Date.new(2025, 9, 3)
    )

    location = WeatherLocation.first
    assert_not_nil location, "WeatherLocation should be created"
    original_data = location.weather_data.where(date: Date.new(2025, 9, 1)).first
    assert_not_nil original_data, "WeatherDatum should be created"
    original_id = original_data.id

    # Second fetch with same dates (should update, not create new)
    assert_no_difference ['WeatherLocation.count', 'WeatherDatum.count'] do
      FetchWeatherDataJob.perform_now(
        latitude: 35.6762,
        longitude: 139.6503,
        start_date: Date.new(2025, 9, 1),
        end_date: Date.new(2025, 9, 3)
      )
    end

    # Should be the same record
    location.reload
    updated_data = location.weather_data.where(date: Date.new(2025, 9, 1)).first
    assert_equal original_id, updated_data.id
    assert_equal 1, WeatherLocation.count
    assert_equal 3, WeatherDatum.count
  end

  test "has retry configuration" do
    # リトライ機能の定数が設定されていることを確認
    assert_equal 5, FetchWeatherDataJob::MAX_RETRY_ATTEMPTS
  end

  test "handles API errors gracefully" do
    skip "Test requires agrr command" unless File.exist?(Rails.root.join('lib', 'core', 'agrr'))

    user = users(:one)
    farm = Farm.create!(
      name: "Test Farm",
      latitude: 999.0,  # 不正な緯度でエラーを発生させる
      longitude: 999.0,  # 不正な経度でエラーを発生させる
      user: user,
      weather_data_status: 'fetching',
      weather_data_total_years: 1,
      weather_data_fetched_years: 0
    )

    # エラーが発生することを確認
    assert_raises(StandardError) do
      FetchWeatherDataJob.perform_now(
        latitude: farm.latitude,
        longitude: farm.longitude,
        start_date: Date.new(2025, 9, 1),
        end_date: Date.new(2025, 9, 1),
        farm_id: farm.id
      )
    end
  end
end

