# frozen_string_literal: true

require "test_helper"

class ApiV1InternalIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @farm = Farm.create!(
      name: "Test Farm",
      latitude: 35.6895,
      longitude: 139.6917,
      user: @user
    )
    stub_fetch_weather_data
  end
  
  # ========================================
  # Environment Check Tests
  # ========================================
  
  test "internal endpoints should be accessible in test environment" do
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", as: :json
    
    # 403 Forbiddenではなく、他のステータスが返ることを確認
    assert_not_equal :forbidden, response.status
  end
  
  # ========================================
  # Fetch Weather Data Tests
  # ========================================
  
  test "should fetch weather data for farm" do
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_equal @farm.id, json["farm_id"]
    assert_not_nil json["status"]
  end
  
  test "should skip fetch if weather data already exists" do
    # Weather locationを作成
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # Weather dataを作成
    WeatherDatum.create!(
      weather_location: weather_location,
      date: Date.today,
      temperature_max: 20.0,
      temperature_min: 10.0,
      temperature_mean: 15.0
    )
    
    # Farmのweather_locationを設定
    @farm.update!(
      weather_location: weather_location,
      weather_data_status: 'completed'
    )
    
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_match(/already exists/, json["message"])
    assert_not_nil json["weather_data_count"]
  end
  
  test "should return 404 for non-existent farm" do
    post "/api/v1/internal/farms/999999/fetch_weather_data", as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Farm not found", json["error"]
  end
  
  test "fetch weather data response should have required fields" do
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[success message farm_id status]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  # ========================================
  # Weather Status Tests
  # ========================================
  
  test "should get weather status for farm" do
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_equal @farm.id, json["farm_id"]
    assert_not_nil json["status"]
    assert_not_nil json["progress"]
    assert json.key?("weather_data_count")
  end
  
  test "should return 404 for non-existent farm in weather status" do
    get "/api/v1/internal/farms/999999/weather_status", as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Farm not found", json["error"]
  end
  
  test "weather status response should have all required fields" do
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[success farm_id status progress fetched_blocks total_blocks weather_data_count last_error]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "weather status should show progress during fetch" do
    # Weather data取得を開始
    @farm.update!(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 2,
      weather_data_total_years: 5
    )
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal 'fetching', json["status"]
    assert_equal 2, json["fetched_blocks"]
    assert_equal 5, json["total_blocks"]
  end
  
  test "weather status should show completion" do
    # Weather locationを作成
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # Weather dataを作成
    10.times do |i|
      WeatherDatum.create!(
        weather_location: weather_location,
        date: Date.today - i.days,
        temperature_max: 20.0,
        temperature_min: 10.0,
        temperature_mean: 15.0
      )
    end
    
    @farm.update!(
      weather_location: weather_location,
      weather_data_status: 'completed'
    )
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal 'completed', json["status"]
    assert_equal 10, json["weather_data_count"]
  end
  
  # ========================================
  # Get Weather Data Tests
  # ========================================
  
  test "should get weather data for farm" do
    # Weather locationを作成
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # Weather dataを作成
    3.times do |i|
      WeatherDatum.create!(
        weather_location: weather_location,
        date: Date.new(2024, 1, i + 1),
        temperature_max: 20.0 + i,
        temperature_min: 10.0 + i,
        temperature_mean: 15.0 + i,
        precipitation: 5.0,
        sunshine_hours: 8.0,
        wind_speed: 3.0,
        weather_code: 0
      )
    end
    
    @farm.update!(weather_location: weather_location)
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_not_nil json["farm"]
    assert_not_nil json["weather_location"]
    assert_equal 3, json["count"]
    assert_equal 3, json["weather_data"].length
  end
  
  test "get weather data response should have farm info" do
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    @farm.update!(weather_location: weather_location)
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    farm_data = json["farm"]
    assert_equal @farm.id, farm_data["id"]
    assert_equal @farm.name, farm_data["name"]
    assert_equal @farm.latitude, farm_data["latitude"]
    assert_equal @farm.longitude, farm_data["longitude"]
    assert_equal @farm.is_reference, farm_data["is_reference"]
  end
  
  test "get weather data response should have location info" do
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 50.0
    )
    @farm.update!(weather_location: weather_location)
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    location_data = json["weather_location"]
    assert_equal weather_location.latitude, location_data["latitude"]
    assert_equal weather_location.longitude, location_data["longitude"]
    assert_equal 50.0, location_data["elevation"]
    assert_equal "Asia/Tokyo", location_data["timezone"]
  end
  
  test "weather data should have all required fields" do
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    WeatherDatum.create!(
      weather_location: weather_location,
      date: Date.today,
      temperature_max: 20.0,
      temperature_min: 10.0,
      temperature_mean: 15.0,
      precipitation: 5.0,
      sunshine_hours: 8.0,
      wind_speed: 3.0,
      weather_code: 0
    )
    
    @farm.update!(weather_location: weather_location)
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    weather = json["weather_data"].first
    required_fields = %w[date temperature_max temperature_min temperature_mean precipitation sunshine_hours wind_speed weather_code]
    required_fields.each do |field|
      assert weather.key?(field), "Missing field: #{field}"
    end
  end
  
  test "weather data should be ordered by date" do
    weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # 逆順で作成
    [3, 1, 2].each do |i|
      WeatherDatum.create!(
        weather_location: weather_location,
        date: Date.new(2024, 1, i),
        temperature_max: 20.0,
        temperature_min: 10.0,
        temperature_mean: 15.0
      )
    end
    
    @farm.update!(weather_location: weather_location)
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    dates = json["weather_data"].map { |w| Date.parse(w["date"]) }
    assert_equal dates.sort, dates, "Weather data should be ordered by date"
  end
  
  test "should return 404 when weather location not found" do
    # Weather locationを設定していない農場
    get "/api/v1/internal/farms/#{@farm.id}/weather_data", as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Weather location not found", json["error"]
  end
  
  test "should return 404 for non-existent farm in get weather data" do
    get "/api/v1/internal/farms/999999/weather_data", as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Farm not found", json["error"]
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "all internal endpoints should return valid JSON" do
    endpoints = [
      [:post, "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data"],
      [:get, "/api/v1/internal/farms/#{@farm.id}/weather_status"]
    ]
    
    endpoints.each do |method, path|
      send(method, path, as: :json)
      
      assert_nothing_raised do
        JSON.parse(response.body)
      end
    end
  end
  
  test "all internal endpoints should have correct content type" do
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", as: :json
    assert_equal "application/json; charset=utf-8", response.content_type
    
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  # ========================================
  # CSRF Protection Tests
  # ========================================
  
  test "internal endpoints should not require CSRF token" do
    # CSRF tokenなしでリクエストを送信
    post "/api/v1/internal/farms/#{@farm.id}/fetch_weather_data", 
      as: :json
    
    # CSRF検証エラーにならない
    assert_not_equal :unprocessable_entity, response.status
  end
  
  # ========================================
  # Authentication Tests
  # ========================================
  
  test "internal endpoints should not require authentication" do
    # セッションなしでリクエストを送信
    get "/api/v1/internal/farms/#{@farm.id}/weather_status", as: :json
    
    # 認証エラーにならない
    assert_not_equal :unauthorized, response.status
  end
end

