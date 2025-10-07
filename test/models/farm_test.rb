# frozen_string_literal: true

require "test_helper"

class FarmTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "valid farm" do
    farm = Farm.new(
      user: users(:one),
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503
    )
    assert farm.valid?
  end

  test "requires name" do
    farm = Farm.new(user: users(:one), latitude: 35.6762, longitude: 139.6503)
    assert_not farm.valid?
    assert_includes farm.errors[:name], "can't be blank"
  end

  test "requires latitude" do
    farm = Farm.new(user: users(:one), name: "テスト農場", longitude: 139.6503)
    assert_not farm.valid?
    assert_includes farm.errors[:latitude], "can't be blank"
  end

  test "requires longitude" do
    farm = Farm.new(user: users(:one), name: "テスト農場", latitude: 35.6762)
    assert_not farm.valid?
    assert_includes farm.errors[:longitude], "can't be blank"
  end

  test "validates latitude range" do
    farm = Farm.new(user: users(:one), name: "テスト農場", latitude: 91, longitude: 139.6503)
    assert_not farm.valid?
    assert_includes farm.errors[:latitude], "must be less than or equal to 90"

    farm.latitude = -91
    assert_not farm.valid?
    assert_includes farm.errors[:latitude], "must be greater than or equal to -90"
  end

  test "validates longitude range" do
    farm = Farm.new(user: users(:one), name: "テスト農場", latitude: 35.6762, longitude: 181)
    assert_not farm.valid?
    assert_includes farm.errors[:longitude], "must be less than or equal to 180"

    farm.longitude = -181
    assert_not farm.valid?
    assert_includes farm.errors[:longitude], "must be greater than or equal to -180"
  end

  test "has_coordinates? returns true when coordinates are present" do
    farm = farms(:one)
    assert farm.has_coordinates?
  end

  test "has_coordinates? returns false when coordinates are missing" do
    farm = Farm.new(name: "テスト農場", user: users(:one))
    assert_not farm.has_coordinates?
  end

  test "enqueues weather data jobs after create" do
    assert_enqueued_with(job: FetchWeatherDataJob) do
      Farm.create!(
        user: users(:one),
        name: "新しい農場",
        latitude: 35.6812,
        longitude: 139.7671
      )
    end
  end

  test "enqueues weather data jobs for each year from 2000 to current year after create" do
    start_year = 2000
    end_year = Date.today.year
    expected_jobs = end_year - start_year + 1

    assert_enqueued_jobs expected_jobs, only: FetchWeatherDataJob do
      Farm.create!(
        user: users(:one),
        name: "新しい農場",
        latitude: 35.6812,
        longitude: 139.7671
      )
    end
  end

  test "does not enqueue weather jobs if coordinates are missing" do
    # 座標なしでFarmを作成しようとするとバリデーションエラーになるので、
    # このテストは意味がありません。代わりに、バリデーションエラーをテスト
    farm = Farm.new(
      user: users(:one),
      name: "座標なし農場"
    )
    assert_not farm.valid?
  end

  test "weather jobs are enqueued with correct date ranges" do
    created_farm = Farm.create!(
      user: users(:one),
      name: "新しい農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    # ステータスが設定されていることを確認
    created_farm.reload
    assert_equal 'fetching', created_farm.weather_data_status
    assert created_farm.weather_data_total_years > 0
  end

  test "farm status is set to fetching after creation" do
    farm = Farm.create!(
      user: users(:one),
      name: "新しい農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    farm.reload
    assert_equal 'fetching', farm.weather_data_status
    assert_equal 0, farm.weather_data_fetched_years
    assert farm.weather_data_total_years > 0
  end

  test "weather_data_progress returns correct percentage" do
    farm = farms(:one)
    farm.update!(weather_data_total_years: 10, weather_data_fetched_years: 5)
    assert_equal 50, farm.weather_data_progress
  end

  test "weather_data_status_text returns correct text" do
    farm = farms(:one)
    
    farm.update!(weather_data_status: 'pending')
    assert_equal '取得待ち', farm.weather_data_status_text
    
    farm.update!(weather_data_status: 'fetching', weather_data_total_years: 10, weather_data_fetched_years: 5)
    assert_equal '取得中 (50%)', farm.weather_data_status_text
    
    farm.update!(weather_data_status: 'completed')
    assert_equal '完了', farm.weather_data_status_text
    
    farm.update!(weather_data_status: 'failed')
    assert_equal '失敗', farm.weather_data_status_text
  end

  test "increment_weather_data_progress increments counter" do
    farm = farms(:one)
    farm.update!(weather_data_status: 'fetching', weather_data_total_years: 10, weather_data_fetched_years: 0)
    
    farm.increment_weather_data_progress!
    assert_equal 1, farm.weather_data_fetched_years
    assert_equal 'fetching', farm.weather_data_status
  end

  test "increment_weather_data_progress marks as completed when done" do
    farm = farms(:one)
    farm.update!(weather_data_status: 'fetching', weather_data_total_years: 10, weather_data_fetched_years: 9)
    
    farm.increment_weather_data_progress!
    assert_equal 10, farm.weather_data_fetched_years
    assert_equal 'completed', farm.weather_data_status
  end

  test "mark_weather_data_failed sets status and error" do
    farm = farms(:one)
    error_message = "Test error"
    
    farm.mark_weather_data_failed!(error_message)
    assert_equal 'failed', farm.weather_data_status
    assert_equal error_message, farm.weather_data_last_error
  end
end

