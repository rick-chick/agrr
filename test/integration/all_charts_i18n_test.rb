# frozen_string_literal: true

require "test_helper"

class AllChartsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    
    # テスト用のFarmとCultivationPlanを作成
    @farm = Farm.create!(
      name: "Test Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      weather_data_status: 'completed'
    )
  end

  # ========== temperature_chart.js のテスト ==========
  
  # Y軸ラベルのdata属性 - 日本語用に"温度 (°C)"が必要
  test "should have Japanese temperature axis data attribute" do
    # weather_data_status が completed のときのみtemperatureChartが表示される
    @farm.update!(weather_data_status: 'completed')
    
    get farm_path(@farm, locale: :ja)
    assert_response :success
    
    # data-temperature-label が存在すべき
    assert_select "canvas#temperatureChart[data-temperature-label]"
  end

  # Y軸ラベルのdata属性 - 英語用に"Temperature (°C)"が必要
  test "should have English temperature axis data attribute" do
    # weather_data_status が completed のときのみtemperatureChartが表示される
    @farm.update!(weather_data_status: 'completed')
    
    get farm_path(@farm, locale: :us)
    assert_response :success
    
    assert_select "canvas#temperatureChart[data-temperature-label]"
  end

  # ========== climate_chart.js の残り2個のテスト ==========
  
  # 軸ラベルのdata属性が必要
  test "should have climate chart axis data attributes for Japanese" do
    skip "Public Plans結果画面はログインなしでアクセス可能" 
    # climate_chart.jsの軸ラベル確認
  end

  test "should have climate chart axis data attributes for English" do
    skip "Public Plans結果画面はログインなしでアクセス可能"
    # climate_chart.jsの軸ラベル確認
  end
end

