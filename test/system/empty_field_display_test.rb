# frozen_string_literal: true

require "application_system_test_case"

# 作物のついていない圃場が画面に表示されることを確認するE2Eテスト
class EmptyFieldDisplayTest < ApplicationSystemTestCase
  setup do
    # テストデータを作成
    @user = User.create!(
      email: "test_empty_field@agrr.app",
      name: "Empty Field Test User",
      google_id: "test_empty_field_#{Time.current.to_i}",
      is_anonymous: true
    )
    
    @farm = Farm.create!(
      user: @user,
      name: "空圃場テスト農場",
      latitude: 35.6762,
      longitude: 139.6503,
      is_reference: true
    )
    
    @weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      timezone: "Asia/Tokyo",
      elevation: 10.0
    )
    
    @farm.update!(weather_location: @weather_location)
    
    # 簡易気象データを作成
    start_date = Date.current - 6.months
    end_date = Date.current + 6.months
    
    (start_date..end_date).step(7) do |date|  # 週次で作成（パフォーマンス向上）
      @weather_location.weather_data.create!(
        date: date,
        temperature_max: 25.0,
        temperature_min: 15.0,
        temperature_mean: 20.0,
        precipitation: 5.0
      )
    end
    
    # 作付け計画を作成
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 300.0,
      planning_start_date: Date.current,
      planning_end_date: Date.current + 6.months,
      status: 'completed',
      total_profit: 50000.0,
      predicted_weather_data: {
        'latitude' => @farm.latitude,
        'longitude' => @farm.longitude,
        'data' => []
      }
    )
    
    # 圃場を3つ作成（2つは空、1つに作物を配置）
    @field1 = @cultivation_plan.cultivation_plan_fields.create!(name: '圃場A', area: 100.0)
    @field2 = @cultivation_plan.cultivation_plan_fields.create!(name: '圃場B（空）', area: 100.0)
    @field3 = @cultivation_plan.cultivation_plan_fields.create!(name: '圃場C（空）', area: 100.0)
    
    # 作物を作成
    @crop = Crop.create!(
      name: "テスト作物",
      variety: "品種A",
      is_reference: true,
      area_per_unit: 100.0,
      revenue_per_area: 1000.0
    )
    
    @plan_crop = @cultivation_plan.cultivation_plan_crops.create!(
      agrr_crop_id: @crop.id,
      name: @crop.name,
      variety: @crop.variety,
      area_per_unit: @crop.area_per_unit,
      revenue_per_area: @crop.revenue_per_area
    )
    
    # 圃場Aにのみ作物を配置（圃場Bと圃場Cは空のまま）
    @cultivation_plan.field_cultivations.create!(
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.current + 1.month,
      completion_date: Date.current + 2.months,
      cultivation_days: 30,
      area: 100.0,
      estimated_cost: 10000.0,
      optimization_result: {
        'revenue' => 100000.0,
        'profit' => 90000.0,
        'accumulated_gdd' => 500.0
      }
    )
    
    puts "\n=== テストデータ作成完了 ==="
    puts "Plan ID: #{@cultivation_plan.id}"
    puts "圃場1 (#{@field1.name}): 作物数=#{@field1.field_cultivations.count}"
    puts "圃場2 (#{@field2.name}): 作物数=#{@field2.field_cultivations.count}"
    puts "圃場3 (#{@field3.name}): 作物数=#{@field3.field_cultivations.count}"
    puts "========================\n"
  end

  test "作物のついていない圃場が画面に表示される" do
    # 結果ページを開く（直接URL指定）
    visit "/ja/public_plans/results?cultivation_plan_id=#{@cultivation_plan.id}"
    
    # ページの読み込みを待機
    sleep 1
    
    # デバッグ: ページの内容を確認
    puts "\n=== ページ内容（最初の500文字） ==="
    puts page.text[0..500]
    puts "===================================\n"
    
    # ページが正しく表示されているか確認（少なくとも圃場という文字があるはず）
    assert page.has_content?("圃場", wait: 10) || page.has_css?("#gantt-chart-container", wait: 10), 
      "ページが正しく表示されていません"
    
    # ガントチャートコンテナが表示されるまで待機
    assert_selector "#gantt-chart-container", wait: 15
    
    # SVGが描画されるまで待機
    assert_selector "#gantt-chart-container svg", wait: 15
    
    # JavaScriptのganttStateが初期化されるまで待機
    sleep 2
    
    # データベース上の圃場数を確認
    db_field_count = @cultivation_plan.cultivation_plan_fields.count
    puts "📊 DB上の圃場数: #{db_field_count}"
    
    # JavaScript側の圃場数を確認
    ui_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 UI上の圃場数: #{ui_field_count}"
    
    # DB上の圃場数とUI上の圃場数が一致することを確認
    assert_equal db_field_count, ui_field_count, 
      "DB上の圃場数(#{db_field_count})とUI上の圃場数(#{ui_field_count})が一致しません。空の圃場が表示されていない可能性があります。"
    
    # 各圃場の詳細を確認
    field_groups = page.evaluate_script('return ganttState.fieldGroups;')
    puts "\n📊 圃場グループ詳細:"
    field_groups.each do |group|
      cultivations_count = group['cultivations'].length
      puts "  - #{group['fieldName']}: 作物数=#{cultivations_count}"
    end
    
    # 空の圃場が含まれていることを確認
    field_names = field_groups.map { |g| g['fieldName'] }
    assert_includes field_names, '圃場B（空）', "空の圃場（圃場B）が表示されていません"
    assert_includes field_names, '圃場C（空）', "空の圃場（圃場C）が表示されていません"
    
    # 空の圃場の削除ボタンが表示されていることを確認
    # （空の圃場は2つあるので、削除ボタンも2個あるはず）
    delete_btn_count = page.all('.delete-field-btn', wait: 5).count
    puts "📊 削除ボタンの数: #{delete_btn_count}"
    
    assert_operator delete_btn_count, :>=, 2, 
      "空の圃場の削除ボタンが表示されていません（期待: 2個以上、実際: #{delete_btn_count}個）"
    
    # スクリーンショットを保存
    take_screenshot
    
    puts "\n✅ テスト成功: 空の圃場が正しく表示されています\n"
  end
end

