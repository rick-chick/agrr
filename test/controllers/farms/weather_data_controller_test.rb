# frozen_string_literal: true

require "test_helper"

class Farms::WeatherDataControllerTest < ActionDispatch::IntegrationTest
  setup do
    # テストユーザーを作成
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'test123'
    )
    
    # セッションを作成
    @session = Session.create_for_user(@user)
    cookies[:session_id] = @session.session_id
    
    # テスト用の天気ロケーションを作成
    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
    
    # テスト用の農場を作成（天気データ取得ジョブをスキップ）
    @farm = Farm.new(
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    @farm.save!(validate: false)
    @farm.update_columns(weather_data_status: 'completed')
    
    # テスト用の天気データを作成（過去1年分のサンプル）
    365.times do |i|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: Date.today - i.days,
        temperature_max: 25.0 + rand(-5.0..5.0),
        temperature_min: 15.0 + rand(-5.0..5.0),
        temperature_mean: 20.0 + rand(-3.0..3.0),
        precipitation: rand(0.0..10.0)
      )
    end
  end
  
  test "should get weather data for farm with direct association" do
    get farm_weather_data_path(@farm)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success'], "Expected success but got: #{json['message']}"
    assert_equal @farm.id, json['farm']['id']
    assert_equal 365, json['data'].length
    
    # データ構造の検証
    first_data = json['data'].first
    assert_includes first_data.keys, 'date'
    assert_includes first_data.keys, 'temperature_max'
    assert_includes first_data.keys, 'temperature_min'
    assert_includes first_data.keys, 'temperature_mean'
    assert_includes first_data.keys, 'precipitation'
  end
  
  test "should get weather data with custom date range" do
    start_date = (Date.today - 30.days).to_s
    end_date = Date.today.to_s
    
    get farm_weather_data_path(@farm, start_date: start_date, end_date: end_date)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success']
    assert_equal 31, json['data'].length
    assert_equal start_date, json['period']['start_date'].to_s
    assert_equal end_date, json['period']['end_date'].to_s
  end
  
  test "should use default date range when not specified" do
    get farm_weather_data_path(@farm)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success']
    
    # デフォルトは過去1年
    expected_start = (Date.today - 1.year).to_s
    expected_end = Date.today.to_s
    assert_equal expected_start, json['period']['start_date'].to_s
    assert_equal expected_end, json['period']['end_date'].to_s
  end
  
  test "should work with farm using coordinate search fallback" do
    # weather_location_idがnullの農場（後方互換性テスト）
    farm_no_association = Farm.new(
      name: "関連なし農場",
      latitude: @weather_location.latitude + 0.0001,  # 微妙に異なる座標
      longitude: @weather_location.longitude + 0.0001,
      user: @user
    )
    farm_no_association.save!(validate: false)
    farm_no_association.update_columns(
      weather_data_status: 'completed',
      weather_location_id: nil  # 関連なし
    )
    
    get farm_weather_data_path(farm_no_association)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success'], "Coordinate search fallback should work"
  end
  
  test "should return error when no weather location found" do
    # 遠い場所の農場を作成
    farm_far_away = Farm.new(
      name: "遠い農場",
      latitude: 40.0,
      longitude: 140.0,
      user: @user
    )
    farm_far_away.save!(validate: false)
    
    get farm_weather_data_path(farm_far_away)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert_not json['success']
    assert_includes json['message'], '天気データがまだ取得されていません'
    assert_includes json['debug'].keys, 'farm_id'
    assert_includes json['debug'].keys, 'weather_locations_count'
  end
  
  test "should return error when farm not found" do
    get farm_weather_data_path(farm_id: 99999999)
    assert_response :not_found
    
    json = JSON.parse(@response.body)
    assert_not json['success']
    assert_includes json['message'], '見つかりません'
  end
  
  test "should require authentication" do
    # ログアウト
    get auth_test_mock_logout_path
    
    get farm_weather_data_path(@farm)
    assert_response :redirect
  end
  
  test "should not allow access to other user's farm" do
    # 別のユーザーを作成
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: 'other123'
    )
    
    other_farm = Farm.new(
      name: "他人の農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: other_user,
      weather_location: @weather_location
    )
    other_farm.save!(validate: false)
    
    get farm_weather_data_path(other_farm)
    assert_response :not_found
  end
  
  test "should handle empty date range gracefully" do
    # 未来の日付範囲（データがない）
    start_date = (Date.today + 1.year).to_s
    end_date = (Date.today + 2.years).to_s
    
    get farm_weather_data_path(@farm, start_date: start_date, end_date: end_date)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success']
    assert_equal 0, json['data'].length
  end
end

