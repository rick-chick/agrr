# frozen_string_literal: true

require "application_system_test_case"

class CropPaletteSimpleTest < ApplicationSystemTestCase
  def setup
    # アノニマスユーザーを作成
    @user = User.create!(
      email: "anonymous@agrr.app",
      name: "Anonymous User",
      google_id: "anonymous_test",
      is_anonymous: true
    )
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6762,
      longitude: 139.6503,
      is_reference: true,
      region: "Japan"
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
    
    # 参照作物を作成
    @crop1 = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true,
      region: "Japan"
    )
    
    # 作付け計画を作成
    @cultivation_plan = create_completed_cultivation_plan
  end

  test "作物パレットの基本要素が表示される" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # パネルの内容を確認
    assert_text "Add Crops"
    assert_text "トマト"
    
    take_screenshot
  end

  test "作物パレットのトグルボタンをクリックできる" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # トグルボタンをクリック
    toggle_btn = find("#crop-palette-toggle")
    toggle_btn.click
    
    # エラーが発生しないことを確認（JavaScriptエラーのチェック）
    # 実際のエラーチェックはCapybaraのデフォルト機能に依存
    
    take_screenshot
  end

  private

  def visit_results_page
    # テスト環境ではplan_idパラメータが使える
    visit results_public_plans_path(plan_id: @cultivation_plan.id)
  end

  def create_weather_data
    (Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 20.0 + rand(-5.0..10.0),
        temperature_min: 10.0 + rand(-5.0..5.0),
        temperature_mean: 15.0 + rand(-5.0..7.0)
      )
    end
  end

  def create_completed_cultivation_plan
    plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 200.0,
      status: :completed,
      planning_start_date: Date.new(2024, 4, 1),
      planning_end_date: Date.new(2024, 10, 31)
    )
    
    # 2つの圃場を作成
    field1 = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "圃場 1",
      area: 100.0,
      daily_fixed_cost: 1000.0
    )
    
    # 作物を作成
    crop1 = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @crop1.name,
      variety: @crop1.variety,
      agrr_crop_id: @crop1.name
    )
    
    # 栽培スケジュールを作成
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      area: 50.0,
      start_date: Date.new(2024, 4, 15),
      completion_date: Date.new(2024, 8, 20),
      cultivation_days: 127,
      estimated_cost: 50000.0,
      status: :completed
    )
    
    plan
  end

  def take_screenshot
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    screenshot_path = Rails.root.join("tmp", "screenshots", "crop_palette_simple_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end
