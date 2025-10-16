# frozen_string_literal: true

require "application_system_test_case"

class GanttVisualTest < ApplicationSystemTestCase
  test "ガントチャートの視覚的確認" do
    # 簡易的なテストデータを作成
    cultivation_plan = create_test_cultivation_plan
    
    # まず任意のページを訪問
    visit public_plans_path
    
    # Railsのセッションを設定（Capybara::RackTestでのみ動作）
    # システムテストではRailsのセッションに直接アクセスできないため、
    # コントローラー経由でセッションを設定する必要がある
    
    # 代替案: URLパラメータで直接plan_idを渡す
    visit results_public_plans_path(plan_id: cultivation_plan.id)
    
    # ページが読み込まれるまで少し待つ
    sleep 2
    
    # ページ全体のスクリーンショット（エラー前に撮影）
    take_screenshot("01_before_assert")
    
    # ページの内容を出力
    puts "\n📄 ページタイトル: #{page.title}"
    puts "📄 ページURL: #{page.current_url}"
    puts "📄 ページボディの最初の200文字: #{page.text[0..200]}"
    
    # ガントチャートセクションが表示されるまで待機
    if page.has_selector?(".gantt-section", wait: 3)
      puts "✅ ガントチャートセクションが見つかりました"
      take_screenshot("02_gantt_found")
    else
      puts "❌ ガントチャートセクションが見つかりません"
      take_screenshot("02_gantt_not_found")
    end
    
    assert_selector ".gantt-section", wait: 10
    
    # ガントチャートコンテナの確認
    assert_selector "#gantt-chart-container", wait: 5
    take_screenshot("02_gantt_container")
    
    # SVG要素が生成されているか確認
    has_svg = page.has_selector?("#gantt-chart-container svg.custom-gantt-chart", wait: 10)
    puts "✓ Custom SVG gantt element: #{has_svg}"
    take_screenshot("03_gantt_svg")
    
    # ガントチャートの構造を確認
    gantt_info = page.evaluate_script("(function() { var container = document.getElementById('gantt-chart-container'); var svg = container ? container.querySelector('svg.custom-gantt-chart') : null; if (!svg) { return { error: 'SVG not found' }; } var fieldRows = svg.querySelectorAll('.field-row'); var bars = svg.querySelectorAll('.cultivation-bar'); var fieldLabels = svg.querySelectorAll('.field-label'); var barLabels = svg.querySelectorAll('.bar-label'); var containerStyle = window.getComputedStyle(container); return { hasSvg: true, fieldRowCount: fieldRows.length, barCount: bars.length, fieldLabelCount: fieldLabels.length, barLabelCount: barLabels.length, fieldLabels: Array.from(fieldLabels).map(function(l) { return l.textContent.trim(); }), barLabels: Array.from(barLabels).map(function(l) { return l.textContent.trim(); }).slice(0, 5), containerOverflow: containerStyle.overflow, containerOverflowX: containerStyle.overflowX, containerWidth: container.offsetWidth, svgWidth: svg.getAttribute('width') }; })()")
    
    puts "\n📊 カスタムガントチャート情報:"
    puts "  - SVG存在: #{gantt_info['hasSvg']}"
    puts "  - 圃場行数: #{gantt_info['fieldRowCount']}"
    puts "  - バー数: #{gantt_info['barCount']}"
    puts "  - 圃場ラベル数: #{gantt_info['fieldLabelCount']}"
    puts "  - 作物ラベル数: #{gantt_info['barLabelCount']}"
    puts "  - 圃場ラベル: #{gantt_info['fieldLabels']}"
    puts "  - 作物ラベル: #{gantt_info['barLabels']}"
    puts "  - コンテナoverflow: #{gantt_info['containerOverflow']}"
    puts "  - コンテナoverflowX: #{gantt_info['containerOverflowX']}"
    puts "  - コンテナ幅: #{gantt_info['containerWidth']}px"
    puts "  - SVG幅: #{gantt_info['svgWidth']}px"
    
    # 問題点のチェック
    issues = []
    
    if gantt_info['fieldRowCount'] == 0
      issues << "❌ 圃場行が表示されていません"
    end
    
    if gantt_info['barCount'] == 0
      issues << "❌ バーが表示されていません"
    end
    
    if gantt_info['fieldLabelCount'] == 0
      issues << "❌ 圃場ラベルが表示されていません"
    end
    
    if issues.any?
      puts "\n🚨 問題点:"
      issues.each { |issue| puts "  #{issue}" }
    else
      puts "\n✅ 大きな問題は検出されませんでした"
    end
    
    # 最終スクリーンショット
    take_screenshot("04_gantt_final")
    
    # アサーション
    assert gantt_info['hasSvg'], "SVGガントチャートが生成されていません"
    assert gantt_info['fieldRowCount'] > 0, "圃場行が表示されていません"
    assert gantt_info['barCount'] > 0, "バーが表示されていません"
    assert gantt_info['fieldLabelCount'] > 0, "圃場ラベルが表示されていません"
  end
  
  private
  
  def create_test_cultivation_plan
    # テスト用の農場を作成
    user = User.create!(
      email: "test@example.com",
      name: "Test User",
      google_id: "test_#{Time.current.to_i}",
      is_anonymous: true
    )
    
    farm = Farm.create!(
      user: user,
      name: "テスト農場",
      latitude: 43.0642,
      longitude: 141.3469,
      is_reference: true
    )
    
    # 簡易的なテストデータを作成
    plan = CultivationPlan.create!(
      farm: farm,
      total_area: 20.0,
      planning_start_date: Date.new(2026, 3, 1),
      planning_end_date: Date.new(2026, 12, 1),
      total_profit: 50000,
      total_revenue: 60000,
      total_cost: 10000,
      status: 'completed'
    )
    
    # 圃場と作物を作成
    field1 = plan.cultivation_plan_fields.create!(name: "圃場1", area: 10.0, daily_fixed_cost: 10.0)
    field2 = plan.cultivation_plan_fields.create!(name: "圃場2", area: 10.0, daily_fixed_cost: 10.0)
    
    crop1 = plan.cultivation_plan_crops.create!(name: "レタス", variety: "結球レタス", area_per_unit: 1.0, revenue_per_area: 800.0)
    crop2 = plan.cultivation_plan_crops.create!(name: "ニンジン", variety: "五寸ニンジン", area_per_unit: 1.0, revenue_per_area: 800.0)
    crop3 = plan.cultivation_plan_crops.create!(name: "白菜", variety: "結球白菜", area_per_unit: 1.0, revenue_per_area: 800.0)
    
    # 栽培データを作成（圃場1に複数栽培）
    plan.field_cultivations.create!(
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      area: 10.0,
      start_date: Date.new(2026, 5, 3),
      completion_date: Date.new(2026, 6, 28),
      cultivation_days: 57,
      estimated_cost: 570.0,
      status: :completed,
      optimization_result: { profit: 7430.0 }
    )
    
    plan.field_cultivations.create!(
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop2,
      area: 10.0,
      start_date: Date.new(2026, 6, 29),
      completion_date: Date.new(2026, 9, 4),
      cultivation_days: 68,
      estimated_cost: 680.0,
      status: :completed,
      optimization_result: { profit: 7320.0 }
    )
    
    plan.field_cultivations.create!(
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      area: 10.0,
      start_date: Date.new(2026, 9, 6),
      completion_date: Date.new(2026, 11, 3),
      cultivation_days: 59,
      estimated_cost: 590.0,
      status: :completed,
      optimization_result: { profit: 7410.0 }
    )
    
    # 圃場2に1つの栽培
    plan.field_cultivations.create!(
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop3,
      area: 10.0,
      start_date: Date.new(2026, 5, 24),
      completion_date: Date.new(2026, 8, 2),
      cultivation_days: 71,
      estimated_cost: 710.0,
      status: :completed,
      optimization_result: { profit: 7290.0 }
    )
    
    plan
  end
  
  def take_screenshot(name)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    screenshot_path = Rails.root.join("tmp", "screenshots", "#{name}_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot: #{screenshot_path}"
  end
end

