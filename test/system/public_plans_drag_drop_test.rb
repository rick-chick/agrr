# frozen_string_literal: true

require "application_system_test_case"

class PublicPlansDragDropTest < ApplicationSystemTestCase
  setup do
    # アノニマスユーザーを取得
    @anonymous_user = User.anonymous_user
    
    # WeatherLocationを先に作成
    @weather_location = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      timezone: 'Asia/Tokyo'
    )
    
    # 参照農場を作成（日本、東京）
    @farm = Farm.create!(
      user: @anonymous_user,
      name: "東京",
      latitude: @weather_location.latitude,
      longitude: @weather_location.longitude,
      region: 'jp',
      is_reference: true,
      weather_location: @weather_location
    )
    
    # 気象データを作成（最小限）
    # GDD計算に必要な期間のみ作成（90日 + バッファ）
    start_date = Date.current
    end_date = Date.current + 120.days
    (start_date..end_date).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0,
        precipitation: 0.0
      )
    end
    
    # 参照作物を作成（GDD要件付き）
    @crop1 = Crop.create!(
      name: 'トマト',
      variety: '桃太郎',
      is_reference: true,
      region: 'jp',
      area_per_unit: 1.0,
      revenue_per_area: 5000.0,
      agrr_crop_id: 'トマト'
    )
    
    # 作物ステージを作成
    stage1 = @crop1.crop_stages.create!(name: '発芽', order: 1)
    stage1.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 15.0,
      optimal_max: 25.0,
      low_stress_threshold: 10.0,
      high_stress_threshold: 30.0,
      frost_threshold: 5.0,
      max_temperature: 35.0
    )
    stage1.create_thermal_requirement!(required_gdd: 100.0)
    
    stage2 = @crop1.crop_stages.create!(name: '成長', order: 2)
    stage2.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 18.0,
      optimal_max: 28.0,
      low_stress_threshold: 12.0,
      high_stress_threshold: 32.0,
      frost_threshold: 5.0,
      max_temperature: 35.0
    )
    stage2.create_thermal_requirement!(required_gdd: 300.0)
    
    stage3 = @crop1.crop_stages.create!(name: '収穫', order: 3)
    stage3.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0,
      low_stress_threshold: 15.0,
      high_stress_threshold: 35.0,
      frost_threshold: 5.0,
      max_temperature: 38.0
    )
    stage3.create_thermal_requirement!(required_gdd: 500.0)
    
    # 別の作物を作成
    @crop2 = Crop.create!(
      name: 'ニンジン',
      variety: '五寸ニンジン',
      is_reference: true,
      region: 'jp',
      area_per_unit: 0.5,
      revenue_per_area: 3000.0,
      agrr_crop_id: 'ニンジン'
    )
    
    # ニンジンのステージを作成
    carrot_stage1 = @crop2.crop_stages.create!(name: '播種〜発芽', order: 1)
    carrot_stage1.create_temperature_requirement!(
      base_temperature: 5.0,
      optimal_min: 10.0,
      optimal_max: 20.0,
      low_stress_threshold: 5.0,
      high_stress_threshold: 25.0,
      frost_threshold: 0.0,
      max_temperature: 30.0
    )
    carrot_stage1.create_thermal_requirement!(required_gdd: 75.0)
    
    carrot_stage2 = @crop2.crop_stages.create!(name: '発芽〜成長', order: 2)
    carrot_stage2.create_temperature_requirement!(
      base_temperature: 5.0,
      optimal_min: 12.0,
      optimal_max: 22.0,
      low_stress_threshold: 8.0,
      high_stress_threshold: 28.0,
      frost_threshold: 0.0,
      max_temperature: 32.0
    )
    carrot_stage2.create_thermal_requirement!(required_gdd: 300.0)
    
    carrot_stage3 = @crop2.crop_stages.create!(name: '成長〜収穫', order: 3)
    carrot_stage3.create_temperature_requirement!(
      base_temperature: 5.0,
      optimal_min: 15.0,
      optimal_max: 25.0,
      low_stress_threshold: 10.0,
      high_stress_threshold: 30.0,
      frost_threshold: 0.0,
      max_temperature: 35.0
    )
    carrot_stage3.create_thermal_requirement!(required_gdd: 500.0)
    
    # 栽培計画を作成（最適化済み）
    planning_end_date = Date.current + 120.days
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 50.0,
      status: 'completed',
      planning_start_date: Date.current,
      planning_end_date: planning_end_date,
      predicted_weather_data: {
        'latitude' => @farm.latitude,
        'longitude' => @farm.longitude,
        'timezone' => 'Asia/Tokyo',
        'data' => (start_date..end_date).map do |date|
          {
            'time' => date.to_s,
            'temperature_2m_max' => 25.0,
            'temperature_2m_min' => 15.0,
            'temperature_2m_mean' => 20.0,
            'precipitation_sum' => 0.0
          }
        end
      }
    )
    
    # 圃場を作成
    @field1 = @cultivation_plan.cultivation_plan_fields.create!(
      name: '圃場1',
      area: 25.0,
      daily_fixed_cost: 0.0
    )
    
    @field2 = @cultivation_plan.cultivation_plan_fields.create!(
      name: '圃場2',
      area: 25.0,
      daily_fixed_cost: 0.0
    )
    
    # 作物を計画に追加
    @plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
      name: @crop1.name,
      variety: @crop1.variety,
      area_per_unit: @crop1.area_per_unit,
      revenue_per_area: @crop1.revenue_per_area,
      agrr_crop_id: @crop1.id
    )
    
    # 栽培を1つ作成
    @field_cultivation = @cultivation_plan.field_cultivations.create!(
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 120.days,
      cultivation_days: 90,
      area: 1.0,
      estimated_cost: 1000.0,
      status: 'completed',
      optimization_result: {
        revenue: 5000.0,
        profit: 4000.0,
        accumulated_gdd: 900.0
      }
    )
  end
  
  test "作物パレットが表示される" do
    visit "/ja/public_plans/results?plan_id=#{@cultivation_plan.id}"
    
    # 作物パレットが表示されていることを確認
    assert_selector "#crop-palette-panel", visible: true
    assert_text "作物を追加"
    
    # 作物カードが表示されていることを確認
    assert_selector ".crop-palette-card[data-crop-id='#{@crop1.id}']", visible: true
    assert_selector ".crop-palette-card[data-crop-id='#{@crop2.id}']", visible: true
  end
  
  test "作物パレットのトグルボタンが表示される" do
    visit "/ja/public_plans/results?plan_id=#{@cultivation_plan.id}"
    
    # トグルボタンが存在することを確認
    assert_selector "#crop-palette-toggle", visible: true
    
    # パネルが存在することを確認
    assert_selector "#crop-palette-panel", visible: true
    
    # Note: トグル機能の詳細な動作（.collapsedクラスの追加/削除）は
    # JavaScriptの単体テストまたは統合テストで検証する
  end
  
  test "ガントチャートが表示される" do
    visit "/ja/public_plans/results?plan_id=#{@cultivation_plan.id}"
    
    # ガントチャートが表示されていることを確認
    assert_selector "#gantt-chart-container", visible: true
    assert_selector "svg.custom-gantt-chart", visible: true
    
    # 栽培バーが表示されていることを確認
    assert_selector ".cultivation-bar[data-id='#{@field_cultivation.id}']", visible: true
  end
  
  # Note: JavaScriptのドラッグ&ドロップは統合テストでテストする
  # System testではJavaScriptの詳細な動作を完全にテストすることは困難なため、
  # UIの表示とAPIエンドポイントの存在を確認するに留める
end

