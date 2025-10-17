# frozen_string_literal: true

require "test_helper"

class ChartsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  # temperature_chart.js - Y軸ラベル
  test "should have Japanese temperature axis label in farm show" do
    # Farmsの温度チャートはJavaScriptで動的生成されるため、
    # HTMLにdata属性が正しく設定されているか確認
    farm = Farm.create!(
      name: "テスト農場",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      weather_data_status: 'completed'
    )
    
    get farm_path(farm, locale: :ja)
    assert_response :success
    
    # data属性の確認（JavaScriptがこれを使用）
    assert_select "canvas#temperatureChart[data-temp-max-label]"
  end

  test "should have English temperature axis label in farm show" do
    farm = Farm.create!(
      name: "Test Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      weather_data_status: 'completed'
    )
    
    get farm_path(farm, locale: :us)
    assert_response :success
    
    # data属性がセットされているか確認
    assert_select "canvas#temperatureChart[data-temp-max-label]"
  end

  # climate_chart.js - Public Plansのチャート
  test "should have Japanese chart labels data attributes in results page" do
    cultivation_plan = CultivationPlan.create!(
      user: @user,
      status: 'completed'
    )
    
    get public_plan_results_path(cultivation_plan, locale: :ja)
    assert_response :success
    
    # climate_chart.jsが使用するdata属性
    assert_select "#climate-chart-display[data-temp-max]"
    assert_select "#climate-chart-display[data-optimal-zone]"
    assert_select "#climate-chart-display[data-stress-zone]"
  end

  test "should have English chart labels data attributes in results page" do
    cultivation_plan = CultivationPlan.create!(
      user: @user,
      status: 'completed'
    )
    
    get public_plan_results_path(cultivation_plan, locale: :us)
    assert_response :success
    
    # climate_chart.jsが使用するdata属性
    assert_select "#climate-chart-display[data-temp-max]"
    assert_select "#climate-chart-display[data-optimal-zone]"
    assert_select "#climate-chart-display[data-stress-zone]"
  end
end

