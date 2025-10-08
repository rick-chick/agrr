# frozen_string_literal: true

require "test_helper"

class WeatherChartFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'test123'
    )
    
    # セッションを作成
    @session = Session.create_for_user(@user)
    cookies[:session_id] = @session.session_id
    
    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
    
    @farm = Farm.new(
      name: "統合テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    @farm.save!(validate: false)
    @farm.update_columns(weather_data_status: 'completed')
    
    # 天気データを作成
    30.times do |i|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: Date.today - i.days,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0,
        precipitation: 0.0
      )
    end
  end

  test "complete weather chart workflow" do
    # 1. 農場一覧ページにアクセス
    get farms_path
    assert_response :success
    assert_select '.farm-card', minimum: 1
    
    # 2. 農場詳細ページにアクセス
    get farm_path(@farm)
    assert_response :success
    
    # 3. 天気データステータスが表示されている
    assert_select '.weather-section'
    assert_select '#temperatureChart'
    assert_select '#chart-period'
    
    # 4. 天気データAPIにアクセス
    get farm_weather_data_path(@farm)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success']
    assert_equal 30, json['data'].length
    
    # 5. 異なる期間でデータ取得
    get farm_weather_data_path(@farm, start_date: (Date.today - 7.days).to_s, end_date: Date.today.to_s)
    assert_response :success
    
    json = JSON.parse(@response.body)
    assert json['success']
    assert_equal 8, json['data'].length
  end

  test "weather chart not shown when data not completed" do
    # 未完了の農場
    pending_farm = Farm.new(
      name: "未完了農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    pending_farm.save!(validate: false)
    pending_farm.update_columns(weather_data_status: 'pending')
    
    get farm_path(pending_farm)
    assert_response :success
    
    # チャートセクションが表示されない
    assert_select '#temperatureChart', count: 0
  end

  test "fetching status shown while weather data is being fetched" do
    fetching_farm = Farm.new(
      name: "取得中農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    fetching_farm.save!(validate: false)
    fetching_farm.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 3,
      weather_data_total_years: 6
    )
    
    get farm_path(fetching_farm)
    assert_response :success
    
    # 進捗メッセージが表示される
    assert_select '.weather-section'
    assert_select '.info-message', text: /取得中/
  end
  
  test "progress bar has correct attributes for JavaScript updates" do
    fetching_farm = Farm.new(
      name: "進捗バーテスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    fetching_farm.save!(validate: false)
    fetching_farm.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 3,
      weather_data_total_years: 6
    )
    
    get farm_path(fetching_farm)
    assert_response :success
    
    # 進捗バーが表示される
    assert_select '.progress-bar'
    
    # data-progress属性が設定されている
    assert_select '.progress-fill[data-progress="50"]'
    
    # style属性も設定されている（初期表示用）
    assert_select '.progress-fill[style*="width: 50%"]'
  end
  
  test "farm card shows progress bar with correct attributes" do
    fetching_farm = Farm.new(
      name: "カード進捗バーテスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    fetching_farm.save!(validate: false)
    fetching_farm.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 2,
      weather_data_total_years: 5
    )
    
    get farms_path
    assert_response :success
    
    # 農場カードに進捗バーが表示される
    assert_select '.farm-card .progress-bar'
    
    # data-progress属性が設定されている
    assert_select '.farm-card .progress-fill[data-progress="40"]'
    
    # style属性も設定されている（初期表示用）
    assert_select '.farm-card .progress-fill[style*="width: 40%"]'
  end
end
