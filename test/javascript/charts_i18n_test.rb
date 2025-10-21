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
      longitude: 139.6503
    )
    
    # after_create_commit callback overwrites status, so update after creation
    farm.update!(weather_data_status: 'completed')
    
    get farm_path(farm, locale: :ja)
    assert_response :success
    
    # data属性の確認（JavaScriptがこれを使用）
    assert_select "canvas#temperatureChart[data-temp-max-label]"
    assert_select "canvas#temperatureChart[data-no-data]"
  end

  test "should have English temperature axis label in farm show" do
    farm = Farm.create!(
      name: "Test Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503
    )
    
    # after_create_commit callback overwrites status, so update after creation
    farm.update!(weather_data_status: 'completed')
    
    get farm_path(farm, locale: :us)
    assert_response :success
    
    # data属性がセットされているか確認
    assert_select "canvas#temperatureChart[data-temp-max-label]"
    assert_select "canvas#temperatureChart[data-no-data]"
  end

  # climate_chart.js - Public Plansのチャート
  test "should have Japanese chart labels data attributes in results page" do
    # Farmを作成
    farm = Farm.create!(
      name: "テスト農場",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503
    )
    
    cultivation_plan = CultivationPlan.create!(
      farm: farm,
      user: @user,
      total_area: 1000.0,
      plan_type: 'public',
      status: 'completed'
    )
    
    get results_public_plans_path(plan_id: cultivation_plan.id, locale: :ja)
    assert_response :success
    
    # climate_chart.jsが使用するdata属性
    assert_select "#climate-chart-display[data-temp-max]"
    assert_select "#climate-chart-display[data-optimal-zone]"
    assert_select "#climate-chart-display[data-stress-zone]"
    assert_select "#climate-chart-display[data-fetch-error]"
  end

  test "should have English chart labels data attributes in results page" do
    # Farmを作成
    farm = Farm.create!(
      name: "Test Farm",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503
    )
    
    cultivation_plan = CultivationPlan.create!(
      farm: farm,
      user: @user,
      total_area: 1000.0,
      plan_type: 'public',
      status: 'completed'
    )
    
    get results_public_plans_path(plan_id: cultivation_plan.id, locale: :us)
    assert_response :success
    
    # climate_chart.jsが使用するdata属性
    assert_select "#climate-chart-display[data-temp-max]"
    assert_select "#climate-chart-display[data-optimal-zone]"
    assert_select "#climate-chart-display[data-stress-zone]"
    assert_select "#climate-chart-display[data-fetch-error]"
  end
end

