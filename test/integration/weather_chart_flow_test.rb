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
    
    # 天気データを作成（バルクインサートで高速化）
    weather_data_records = []
    now = Time.current
    
    30.times do |i|
      weather_data_records << {
        weather_location_id: @weather_location.id,
        date: Date.today - i.days,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0,
        precipitation: 0.0,
        created_at: now,
        updated_at: now
      }
    end
    
    WeatherDatum.insert_all(weather_data_records) if weather_data_records.any?
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
  
  test "progress bar not shown when progress is 100% in detail view" do
    # 進捗100%の農場（まだfetchingステータス）
    farm_100_percent = Farm.new(
      name: "進捗100%農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    farm_100_percent.save!(validate: false)
    farm_100_percent.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 5,
      weather_data_total_years: 5
    )
    
    get farm_path(farm_100_percent)
    assert_response :success
    
    # 進捗が100%なので進捗バーは表示されない
    assert_select '.weather-section'
    assert_select '.progress-bar', count: 0
    
    # 完了間近のメッセージが表示される
    assert_select '.info-message', text: /完了/
  end
  
  test "progress bar not shown when progress is 100% in list view" do
    # 進捗100%の農場（まだfetchingステータス）
    farm_100_percent = Farm.new(
      name: "リスト進捗100%農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    farm_100_percent.save!(validate: false)
    farm_100_percent.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 5,
      weather_data_total_years: 5
    )
    
    get farms_path
    assert_response :success
    
    # 農場カードに進捗バーが表示されない
    assert_select '.farm-card .progress-bar', count: 0
    
    # 完了間近のメッセージが表示される
    assert_select '.farm-card .info-message', text: /完了/
  end
  
  test "increment_weather_data_progress updates progress correctly" do
    test_farm = Farm.new(
      name: "進捗更新テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user
    )
    test_farm.save!(validate: false)
    test_farm.update_columns(
      weather_data_status: 'fetching',
      weather_data_fetched_years: 0,
      weather_data_total_years: 5
    )
    
    # 最初の進捗更新
    test_farm.increment_weather_data_progress!
    test_farm.reload
    assert_equal 1, test_farm.weather_data_fetched_years
    assert_equal 20, test_farm.weather_data_progress
    assert_equal 'fetching', test_farm.weather_data_status
    
    # 2回目の進捗更新
    test_farm.increment_weather_data_progress!
    test_farm.reload
    assert_equal 2, test_farm.weather_data_fetched_years
    assert_equal 40, test_farm.weather_data_progress
    assert_equal 'fetching', test_farm.weather_data_status
    
    # 3回目の進捗更新
    test_farm.increment_weather_data_progress!
    test_farm.reload
    assert_equal 3, test_farm.weather_data_fetched_years
    assert_equal 60, test_farm.weather_data_progress
    assert_equal 'fetching', test_farm.weather_data_status
    
    # 4回目の進捗更新
    test_farm.increment_weather_data_progress!
    test_farm.reload
    assert_equal 4, test_farm.weather_data_fetched_years
    assert_equal 80, test_farm.weather_data_progress
    assert_equal 'fetching', test_farm.weather_data_status
    
    # 最後の進捗更新（完了）
    test_farm.increment_weather_data_progress!
    test_farm.reload
    assert_equal 5, test_farm.weather_data_fetched_years
    assert_equal 100, test_farm.weather_data_progress
    assert_equal 'completed', test_farm.weather_data_status
  end
  
  test "updating farm coordinates resets weather data and triggers new fetch" do
    # 天気データが完了している農場を作成
    completed_farm = Farm.new(
      name: "完了済み農場",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    completed_farm.save!(validate: false)
    completed_farm.update_columns(
      weather_data_status: 'completed',
      weather_data_fetched_years: 5,
      weather_data_total_years: 5
    )
    
    assert_equal @weather_location.id, completed_farm.weather_location_id
    assert_equal 'completed', completed_farm.weather_data_status
    
    # 緯度経度を更新（新しい天気データ取得が自動的に始まる）
    completed_farm.update!(
      latitude: 34.0,
      longitude: 135.0
    )
    
    # weather_locationとの関連が切れる
    assert_nil completed_farm.weather_location_id
    
    # 新しい天気データ取得が始まるため、ステータスはfetchingになる
    assert_equal 'fetching', completed_farm.weather_data_status
    
    # 進捗は新しい取得用に初期化される
    assert_equal 0, completed_farm.weather_data_fetched_years
    assert completed_farm.weather_data_total_years > 0, "Total years should be set for new fetch"
  end
  
  test "updating farm name does not reset weather data" do
    # 天気データが完了している農場を作成
    completed_farm = Farm.new(
      name: "元の名前",
      latitude: 35.6812,
      longitude: 139.7671,
      user: @user,
      weather_location: @weather_location
    )
    completed_farm.save!(validate: false)
    completed_farm.update_columns(
      weather_data_status: 'completed',
      weather_data_fetched_years: 5,
      weather_data_total_years: 5
    )
    
    original_location_id = completed_farm.weather_location_id
    
    # 名前だけを更新
    completed_farm.update!(name: "新しい名前")
    
    # weather_locationとの関連は維持される
    assert_equal original_location_id, completed_farm.weather_location_id
    
    # ステータスは変わらない
    assert_equal 'completed', completed_farm.weather_data_status
    assert_equal 5, completed_farm.weather_data_fetched_years
    assert_equal 5, completed_farm.weather_data_total_years
  end
end
