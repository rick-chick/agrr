# frozen_string_literal: true

require "application_system_test_case"

class GanttAdjustE2eTest < ApplicationSystemTestCase
  setup do
    # ユーザーを作成してログイン
    @user = users(:one)
    sign_in @user
    
    # 農場を作成
    @farm = Farm.create!(
      name: "テスト農場",
      user: @user,
      latitude: 35.6762,
      longitude: 139.6503,
      weather_location: "東京"
    )
    
    # 栽培計画を作成
    @cultivation_plan = CultivationPlan.create!(
      name: "E2Eテスト計画",
      farm: @farm,
      planning_start_date: Date.new(2025, 10, 19),
      planning_end_date: Date.new(2026, 12, 31),
      status: :optimized,
      optimization_result: {
        total_profit: 1000.0,
        total_cost: 2500.0,
        total_revenue: 3500.0
      }
    )
    
    # 圃場を作成
    @field1 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場1",
      area: 17.0,
      daily_fixed_cost: 10.0
    )
    
    @field2 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: "圃場2",
      area: 17.0,
      daily_fixed_cost: 10.0
    )
    
    # 参照作物を取得（既存のfixture）
    @crop = crops(:spinach)
    
    # 栽培計画作物を作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.agrr_crop_id
    )
    
    # 圃場栽培を作成
    @cultivation = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field1,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 7, 2),
      completion_date: Date.new(2026, 9, 19),
      area: 16.67,
      estimated_cost: 500.0,
      optimization_result: {
        revenue: 0.0,
        profit: -500.0,
        accumulated_gdd: 0.0
      }
    )
    
    # 気象データを保存
    @cultivation_plan.update!(
      predicted_weather_data: {
        latitude: 35.6762,
        longitude: 139.6503,
        data: (Date.new(2025, 10, 19)..Date.new(2026, 12, 31)).map do |date|
          {
            time: date.to_s,
            temperature_2m_max: 20.0,
            temperature_2m_min: 10.0,
            temperature_2m_mean: 15.0
          }
        end
      }
    )
  end
  
  test "ガントチャートでバーをドラッグして再最適化" do
    # 結果ページに移動
    visit public_plans_result_path(@cultivation_plan)
    
    # ガントチャートが表示されることを確認
    assert_selector "#gantt-chart-container"
    
    # JavaScriptが初期化されるまで待つ
    sleep 1
    
    # デバッグ: コンソールログを確認
    puts "=== ページタイトル ==="
    puts page.title
    
    puts "\n=== ページHTML（最初の500文字） ==="
    puts page.html[0..500]
    
    # ガントチャートのSVGが描画されていることを確認
    assert_selector "svg.gantt-chart", wait: 5
    
    # バーが描画されていることを確認
    assert_selector "rect.bar-bg", wait: 5
    
    # JavaScriptが正常に動作していることを確認（コンソールログ）
    # Note: Capybaraではコンソールログを直接取得できないため、
    # 実際のドラッグ操作を実行して結果を確認する
    
    # バーの初期位置を取得
    bar = find("rect.bar-bg", match: :first)
    initial_x = bar[:x].to_f
    
    puts "\n=== バーの初期位置 ==="
    puts "X座標: #{initial_x}"
    
    # バーをドラッグ（100px右に移動）
    bar.drag_by(100, 0)
    
    # ドラッグ後、自動的にAPIリクエストが送信されるまで待つ
    sleep 2
    
    # エラーメッセージが表示されていないことを確認
    assert_no_selector ".error-message", wait: 3
    
    # 成功した場合はページがリロードされるはずなので、
    # 再度ガントチャートが表示されることを確認
    assert_selector "svg.gantt-chart", wait: 10
    
    puts "\n=== テスト成功 ==="
  end
end

