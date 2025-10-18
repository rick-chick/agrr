# frozen_string_literal: true

require "test_helper"

class PublicPlansControllerTest < ActionDispatch::IntegrationTest
  def setup
    # アノニマスユーザーを作成
    @user = User.create!(
      email: 'test@agrr.app',
      name: 'Test User',
      google_id: 'test123',
      is_anonymous: true
    )
    
    # JP参照農場を作成
    @farm = Farm.create!(
      user: @user,
      name: "北海道・札幌",
      latitude: 43.0642,
      longitude: 141.3469,
      is_reference: true,
      region: 'jp'
    )
    
    # US参照農場を作成（地域選択タブ表示のため）
    @us_farm = Farm.create!(
      user: @user,
      name: "Kern County, CA",
      latitude: 35.3733,
      longitude: -119.0187,
      is_reference: true,
      region: 'us'
    )
    
    # 天気ロケーションを作成
    @weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    # 天気データを作成
    create_weather_data
    
    # JP参照作物を作成
    @crop = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true,
      region: 'jp'
    )
    
    # US参照作物を作成
    @us_crop = Crop.create!(
      name: "Corn",
      variety: "Field Corn",
      is_reference: true,
      region: 'us'
    )
    
    # JP用のInteractionRulesを作成
    InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "ナス科",
      target_group: "ナス科",
      impact_ratio: 0.6,
      is_directional: true,
      is_reference: true,
      region: 'jp',
      description: "ナス科の連作"
    )
    
    # US用のInteractionRulesを作成
    InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Poaceae",
      target_group: "Poaceae",
      impact_ratio: 0.95,
      is_directional: true,
      is_reference: true,
      region: 'us',
      description: "Poaceae continuous cultivation"
    )
  end

  # ========================================
  # results アクション
  # ========================================
  
  test "should get results with valid cultivation plan" do
    cultivation_plan = create_completed_cultivation_plan
    
    # セッションに計画IDを設定
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-results-header"
    assert_select ".gantt-section"
    assert_select ".gantt-table"
  end
  
  test "results should display header with summary" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-results-header-title", "作付け計画完成"
    assert_select ".gantt-summary-item", count: 4 # 地域、総面積、圃場数、推定総コスト
  end
  
  test "results should display gantt chart" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-table"
    assert_select ".gantt-header-year", count: 2 # 2024年、2025年
    assert_select ".gantt-row", count: cultivation_plan.field_cultivations.count
  end
  
  test "results should display gantt row with field and crop info" do
    cultivation_plan = create_completed_cultivation_plan
    fc = cultivation_plan.field_cultivations.first
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-row[data-field-cultivation-id='#{fc.id}']" do
      assert_select ".field-name", text: /#{fc.field_display_name}/
      assert_select ".crop-name", text: /#{fc.crop_display_name}/
    end
  end
  
  test "results should display cultivation bar" do
    cultivation_plan = create_completed_cultivation_plan
    fc = cultivation_plan.field_cultivations.first
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-cultivation-bar"
    assert_select ".bar-start-date", text: /#{fc.start_date.strftime('%-m/%-d')}/
    assert_select ".bar-end-date", text: /#{fc.completion_date.strftime('%-m/%-d')}/
  end
  
  test "results should display detail panel" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".detail-panel"
    assert_select ".detail-panel-tabs"
    assert_select ".detail-tab-btn", count: 3 # 基本情報、気温分析、ステージ
  end
  
  test "results should display tab content templates" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select "#tab-info-content"
    assert_select "#tab-temperature-content"
    assert_select "#tab-stages-content"
  end
  
  test "results should display info tab with cards" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select "#tab-info-content" do
      assert_select ".info-card", count: 8 # 圃場、作物、面積、播種日、収穫日、栽培日数、積算温度、コスト
    end
  end
  
  test "results should display temperature tab with chart containers" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select "#tab-temperature-content" do
      assert_select "#temperatureChart"
      assert_select "#gddChart"
      assert_select ".stat-card", count: 3
    end
  end
  
  test "results should display stages tab" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select "#tab-stages-content" do
      assert_select ".stages-list"
    end
  end
  
  test "results should display CTA card" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-cta-card"
    assert_select ".gantt-cta-title", text: /もっと詳しい分析が必要ですか/
    assert_select "a[href='#{auth_login_path}']", text: /無料で会員登録/
  end
  
  test "results should display action buttons" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".action-buttons"
    assert_select "a[href='#{public_plans_path}']", text: /新しい計画を作成/
  end
  
  test "results should redirect when plan_id is missing in session" do
    get results_public_plans_path
    
    assert_redirected_to public_plans_path
  end
  
  test "results should redirect when plan not found" do
    get results_public_plans_path, params: { plan_id: 999999 }
    
    assert_redirected_to public_plans_path
  end
  
  test "results should redirect to optimizing if plan is not completed" do
    cultivation_plan = create_pending_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_redirected_to optimizing_public_plans_path
  end
  
  test "results should include Chart.js scripts" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select "script[src*='chart.js']"
    assert_select "script[src*='chartjs-adapter-date-fns']"
  end
  
  # ========================================
  # ガントチャート表示のエッジケース
  # ========================================
  
  test "gantt chart should handle multiple field cultivations" do
    cultivation_plan = create_cultivation_plan_with_multiple_crops
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-row", count: 3
  end
  
  test "gantt chart should display today marker" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-today-marker-row"
    assert_select ".today-marker-icon", text: "📍"
  end
  
  test "gantt chart should display legend" do
    cultivation_plan = create_completed_cultivation_plan
    
    get results_public_plans_path, params: { plan_id: cultivation_plan.id }
    
    assert_response :success
    assert_select ".gantt-legend"
    assert_select ".legend-color.stage-germination"
    assert_select ".legend-color.stage-growth"
    assert_select ".legend-color.stage-flowering"
    assert_select ".legend-color.stage-fruiting"
    assert_select ".legend-color.stage-harvest"
  end
  
  # ========================================
  # ヘルパーメソッド
  # ========================================
  
  private
  
  def create_weather_data
    # 2024年の天気データを作成
    (Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 20.0 + rand(-5.0..10.0),
        temperature_min: 10.0 + rand(-5.0..5.0),
        temperature_mean: 15.0 + rand(-5.0..7.0),
        precipitation: rand(0.0..10.0),
        sunshine_hours: rand(0.0..12.0)
      )
    end
  end
  
  def create_completed_cultivation_plan
    # 圃場計画を作成
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      session_id: 'test_session_123',
      total_area: 100.0,
      status: :completed
    )
    
    # 圃場を作成
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "第1圃場",
      area: 100.0,
      daily_fixed_cost: 1000.0
    )
    
    # 作物を作成
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.name
    )
    
    # 圃場栽培を作成
    fc = FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 100.0,
      start_date: Date.new(2024, 4, 15),
      completion_date: Date.new(2024, 8, 20),
      cultivation_days: 127,
      estimated_cost: 85000.0,
      status: :completed,
      optimization_result: {
        start_date: "2024-04-15",
        completion_date: "2024-08-20",
        days: 127,
        cost: 85000.0,
        gdd: 2456.0,
        raw: {
          stages: [
            { name: "発芽", start_date: "2024-04-15", end_date: "2024-04-30", days: 15, gdd: 200 },
            { name: "成長", start_date: "2024-05-01", end_date: "2024-06-30", days: 60, gdd: 1200 },
            { name: "開花", start_date: "2024-07-01", end_date: "2024-07-20", days: 20, gdd: 400 },
            { name: "結実", start_date: "2024-07-21", end_date: "2024-08-10", days: 20, gdd: 400 },
            { name: "収穫", start_date: "2024-08-11", end_date: "2024-08-20", days: 10, gdd: 256 }
          ]
        }
      }
    )
    
    plan
  end
  
  def create_pending_cultivation_plan
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      session_id: 'test_session_123',
      total_area: 100.0,
      status: :pending
    )
    
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "第1圃場",
      area: 100.0,
      daily_fixed_cost: 1000.0
    )
    
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.name
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 100.0,
      status: :pending
    )
    
    plan
  end
  
  def create_cultivation_plan_with_multiple_crops
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      session_id: 'test_session_123',
      total_area: 300.0,
      status: :completed
    )
    
    # 3つの作物を作成
    crops_data = [
      { name: "トマト", variety: "桃太郎", start: Date.new(2024, 4, 15), end: Date.new(2024, 8, 20) },
      { name: "キュウリ", variety: "夏すずみ", start: Date.new(2024, 5, 1), end: Date.new(2024, 7, 15) },
      { name: "ナス", variety: "千両", start: Date.new(2024, 4, 20), end: Date.new(2024, 9, 10) }
    ]
    
    crops_data.each_with_index do |crop_data, index|
      field = CultivationPlanField.create!(
        cultivation_plan: plan,
        name: "第#{index + 1}圃場",
        area: 100.0,
        daily_fixed_cost: 1000.0
      )
      
      crop = CultivationPlanCrop.create!(
        cultivation_plan: plan,
        name: crop_data[:name],
        variety: crop_data[:variety],
        agrr_crop_id: crop_data[:name]
      )
      
      days = (crop_data[:end] - crop_data[:start]).to_i
      
      FieldCultivation.create!(
        cultivation_plan: plan,
        cultivation_plan_field: field,
        cultivation_plan_crop: crop,
        area: 100.0,
        start_date: crop_data[:start],
        completion_date: crop_data[:end],
        cultivation_days: days,
        estimated_cost: 85000.0,
        status: :completed,
        optimization_result: { gdd: 2400.0, raw: { stages: [] } }
      )
    end
    
    plan
  end
  
  # ========================================
  # Region Filtering Tests (locale-based)
  # ========================================
  
  test "should default to jp region when locale is ja" do
    get public_plans_path(locale: 'ja')
    assert_response :success
    # JP farm should be displayed
    assert_select ".enhanced-card-title", text: @farm.name
  end
  
  test "should filter farms by locale (/ja shows jp farms, /us shows us farms)" do
    # Test /ja locale → jp region
    get public_plans_path(locale: 'ja')
    assert_response :success
    assert_select ".enhanced-card-title", text: @farm.name
    assert_select ".enhanced-card-title", text: @us_farm.name, count: 0
    
    # Test /us locale → us region
    get public_plans_path(locale: 'us')
    assert_response :success
    assert_select ".enhanced-card-title", text: @us_farm.name
    assert_select ".enhanced-card-title", text: @farm.name, count: 0
  end
  
  test "should filter crops by farm region based on locale" do
    # Select JP farm (locale: ja)
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @farm.id)
    assert_response :success
    
    get select_crop_public_plans_path(locale: 'ja', params: { farm_size_id: 'home_garden' })
    assert_response :success
    
    # Should show JP crop only
    assert_select ".crop-name", text: @crop.name
    assert_select ".crop-name", text: @us_crop.name, count: 0
  end
end

