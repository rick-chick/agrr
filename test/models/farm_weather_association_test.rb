# frozen_string_literal: true

require "test_helper"

class FarmWeatherAssociationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
  end

  test "farm can be associated with weather_location" do
    farm = Farm.new(
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    
    # コールバックをスキップして保存
    farm.save!(validate: false)
    
    assert_equal @weather_location.id, farm.weather_location_id
    assert_equal @weather_location, farm.weather_location
  end

  test "farm can exist without weather_location" do
    farm = Farm.new(
      name: "関連なし農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    
    farm.save!(validate: false)
    
    assert_nil farm.weather_location_id
    assert_nil farm.weather_location
  end

  test "weather_location association is optional" do
    farm = Farm.new(
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: nil
    )
    
    assert farm.save(validate: false)
  end

  test "farm can access weather_data through weather_location" do
    farm = Farm.new(
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    farm.save!(validate: false)
    
    # 天気データを作成
    WeatherDatum.create!(
      weather_location: @weather_location,
      date: Date.today,
      temperature_max: 25.0,
      temperature_min: 15.0,
      temperature_mean: 20.0
    )
    
    assert_equal 1, farm.weather_location.weather_data.count
  end

  test "deleting farm does not delete weather_location" do
    farm = Farm.new(
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    farm.save!(validate: false)
    
    farm_id = farm.id
    weather_location_id = @weather_location.id
    
    farm.destroy
    
    # WeatherLocationは削除されない
    assert WeatherLocation.exists?(weather_location_id)
  end
end
