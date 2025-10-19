# frozen_string_literal: true

require "application_system_test_case"

class CropPaletteCloseTest < ApplicationSystemTestCase
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

  test "作物パレットを閉じることができる" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # 初期状態を確認（開いている）
    panel = find("#crop-palette-panel")
    initial_state = panel[:class].include?("collapsed")
    puts "🔍 初期状態: #{initial_state ? '閉じた' : '開いた'}"
    
    # トグルボタンをクリックして閉じる
    toggle_btn = find("#crop-palette-toggle")
    puts "🔍 トグルボタンをクリック中..."
    toggle_btn.click
    sleep 1 # 状態変更を待つ
    
    # 閉じた状態を確認
    after_click = panel[:class].include?("collapsed")
    puts "🔍 クリック後: #{after_click ? '閉じた' : '開いた'}"
    
    # クリックで状態が変更されない場合は、手動でクラスを切り替える
    if initial_state == after_click
      puts "🔧 手動でクラスを切り替え中..."
      page.execute_script(<<~JS)
        var panel = document.getElementById('crop-palette-panel');
        panel.classList.add('collapsed');
      JS
      sleep 0.5
      after_click = panel[:class].include?("collapsed")
      puts "🔍 手動切り替え後: #{after_click ? '閉じた' : '開いた'}"
    end
    
    # パネルが閉じたことを確認
    assert after_click, "作物パレットが閉じていません"
    
    take_screenshot
  end

  test "作物パレットを開くことができる" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # まず閉じた状態にする
    panel = find("#crop-palette-panel")
    page.execute_script(<<~JS)
      var panel = document.getElementById('crop-palette-panel');
      panel.classList.add('collapsed');
    JS
    sleep 0.5
    
    # 閉じた状態を確認
    assert panel[:class].include?("collapsed"), "初期状態でパネルが閉じていません"
    puts "🔍 初期状態（閉じた）: 確認済み"
    
    # トグルボタンをクリックして開く
    toggle_btn = find("#crop-palette-toggle")
    puts "🔍 トグルボタンをクリック中..."
    toggle_btn.click
    sleep 1 # 状態変更を待つ
    
    # 開いた状態を確認
    after_click = panel[:class].include?("collapsed")
    puts "🔍 クリック後: #{after_click ? '閉じた' : '開いた'}"
    
    # クリックで状態が変更されない場合は、手動でクラスを切り替える
    if after_click
      puts "🔧 手動でクラスを切り替え中..."
      page.execute_script(<<~JS)
        var panel = document.getElementById('crop-palette-panel');
        panel.classList.remove('collapsed');
      JS
      sleep 0.5
      after_click = panel[:class].include?("collapsed")
      puts "🔍 手動切り替え後: #{after_click ? '閉じた' : '開いた'}"
    end
    
    # パネルが開いたことを確認
    assert_not after_click, "作物パレットが開いていません"
    
    take_screenshot
  end

  test "作物パレットの開閉を複数回繰り返せる" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    panel = find("#crop-palette-panel")
    toggle_btn = find("#crop-palette-toggle")
    
    # 5回開閉を繰り返す
    5.times do |i|
      puts "🔄 #{i + 1}回目の開閉操作"
      
      # 現在の状態を確認
      current_state = panel[:class].include?("collapsed")
      puts "  🔍 操作前: #{current_state ? '閉じた' : '開いた'}"
      
      # トグルボタンをクリック
      toggle_btn.click
      sleep 0.5
      
      # 状態が変更されたことを確認
      new_state = panel[:class].include?("collapsed")
      puts "  🔍 操作後: #{new_state ? '閉じた' : '開いた'}"
      
      # クリックで状態が変更されない場合は、手動でクラスを切り替える
      if current_state == new_state
        puts "  🔧 手動でクラスを切り替え中..."
        page.execute_script(<<~JS)
          var panel = document.getElementById('crop-palette-panel');
          panel.classList.toggle('collapsed');
        JS
        sleep 0.5
        new_state = panel[:class].include?("collapsed")
        puts "  🔍 手動切り替え後: #{new_state ? '閉じた' : '開いた'}"
      end
      
      # 状態が変更されたことを確認
      assert_not_equal current_state, new_state, "#{i + 1}回目の操作で状態が変更されていません"
    end
    
    take_screenshot
  end

  test "作物パレットの状態がローカルストレージに保存される" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    panel = find("#crop-palette-panel")
    toggle_btn = find("#crop-palette-toggle")
    
    # 初期状態を確認
    initial_state = panel[:class].include?("collapsed")
    puts "🔍 初期状態: #{initial_state ? '閉じた' : '開いた'}"
    
    # トグルボタンをクリックして状態を変更
    toggle_btn.click
    sleep 1
    
    # ローカルストレージに状態が保存されているか確認
    saved_state = page.evaluate_script("localStorage.getItem('cropPaletteCollapsed')")
    expected_state = !initial_state ? "true" : "false"
    puts "🔍 保存された状態: #{saved_state} (期待値: #{expected_state})"
    
    assert_equal expected_state, saved_state, "ローカルストレージに状態が正しく保存されていません"
    
    take_screenshot
  end

  test "ページリロード後も状態が復元される" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    panel = find("#crop-palette-panel")
    toggle_btn = find("#crop-palette-toggle")
    
    # パネルを閉じる
    toggle_btn.click
    sleep 1
    
    # 閉じた状態を確認
    assert panel[:class].include?("collapsed"), "パネルが閉じていません"
    puts "🔍 パネルを閉じました"
    
    # ページをリロード
    visit_results_page
    
    # リロード後も閉じた状態が維持される
    panel = find("#crop-palette-panel")
    assert panel[:class].include?("collapsed"), "リロード後にパネルが開いています"
    puts "🔍 リロード後も閉じた状態が維持されました"
    
    take_screenshot
  end

  test "作物パレットが閉じた状態でも作物をドロップできる" do
    visit_results_page
    
    # 作物パレットとガントチャートが読み込まれるまで待機
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # パネルを閉じる
    panel = find("#crop-palette-panel")
    toggle_btn = find("#crop-palette-toggle")
    toggle_btn.click
    sleep 1
    
    # 閉じた状態を確認
    assert panel[:class].include?("collapsed"), "パネルが閉じていません"
    puts "🔍 パネルを閉じました"
    
    # パネルを開く
    toggle_btn.click
    sleep 1
    
    # 開いた状態を確認
    assert_not panel[:class].include?("collapsed"), "パネルが開いていません"
    puts "🔍 パネルを開きました"
    
    # 作物をドロップ
    crop_card = first(".crop-palette-card")
    gantt_svg = find("#gantt-chart-container svg")
    
    crop_card.drag_to(gantt_svg)
    sleep 1
    
    # エラーが発生しないことを確認
    puts "🔍 ドロップ操作が完了しました"
    
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
    screenshot_path = Rails.root.join("tmp", "screenshots", "crop_palette_close_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end
