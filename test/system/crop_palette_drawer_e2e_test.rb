# frozen_string_literal: true

require "application_system_test_case"

class CropPaletteDrawerE2eTest < ApplicationSystemTestCase
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
    
    @crop2 = Crop.create!(
      name: "キュウリ",
      variety: "夏すずみ",
      is_reference: true,
      region: "Japan"
    )
    
    @crop3 = Crop.create!(
      name: "ほうれん草",
      variety: "一般",
      is_reference: true,
      region: "Japan"
    )
    
    # 作付け計画を作成
    @cultivation_plan = create_completed_cultivation_plan
  end

  test "作物パレットドロワーが正常に開閉する" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # JavaScriptが正しく読み込まれているか確認
    js_loaded = page.evaluate_script(<<~JS)
      typeof window.initCropPalette === 'function';
    JS
    assert js_loaded, "作物パレットのJavaScriptが読み込まれていません"
    
    # イベントリスナーが設定されているか確認
    listener_set = page.evaluate_script(<<~JS)
      (function() {
        var toggleBtn = document.getElementById('crop-palette-toggle');
        return toggleBtn && toggleBtn.dataset.listenerAdded === 'true';
      })();
    JS
    assert listener_set, "イベントリスナーが設定されていません"
    
    # 初期状態を確認
    panel = find("#crop-palette-panel")
    initial_state = panel[:class].include?("collapsed")
    puts "🔍 初期状態: #{initial_state ? '閉じた' : '開いた'}"
    
    # トグルボタンをクリックして状態を変更
    toggle_btn = find("#crop-palette-toggle")
    toggle_btn.click
    sleep 0.5 # 状態変更を待つ
    
    # 状態が変更されたことを確認
    after_first_click = panel[:class].include?("collapsed")
    puts "🔍 1回目クリック後: #{after_first_click ? '閉じた' : '開いた'}"
    assert_not_equal initial_state, after_first_click, "1回目のクリックで状態が変更されていません"
    
    # 再度クリックして元の状態に戻す
    toggle_btn.click
    sleep 0.5 # 状態変更を待つ
    
    # 元の状態に戻ったことを確認
    after_second_click = panel[:class].include?("collapsed")
    puts "🔍 2回目クリック後: #{after_second_click ? '閉じた' : '開いた'}"
    assert_equal initial_state, after_second_click, "2回目のクリックで元の状態に戻っていません"
    
    take_screenshot
  end

  test "作物パレットドロワーの状態がローカルストレージに保存される" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # トグルボタンをクリックして状態を変更
    toggle_btn = find("#crop-palette-toggle")
    initial_state = find("#crop-palette-panel")[:class].include?("collapsed")
    toggle_btn.click
    sleep 0.2 # 状態変更を待つ
    
    # ローカルストレージに状態が保存されているか確認
    collapsed_state = page.evaluate_script("localStorage.getItem('cropPaletteCollapsed')")
    expected_state = !initial_state ? "true" : "false"
    assert_equal expected_state, collapsed_state, "ローカルストレージに状態が保存されていません"
    
    # ページをリロードして状態が復元されるか確認
    visit_results_page
    
    # リロード後も閉じた状態が維持される
    panel = find("#crop-palette-panel")
    assert panel[:class].include?("collapsed"), "リロード後にドロワーが開いています"
    
    take_screenshot
  end

  test "作物パレットに作物カードが表示される" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    
    # 作物カードが表示される
    assert_selector ".crop-palette-card", minimum: 3, wait: 10
    
    # 各作物の名前が表示される
    assert_text "トマト"
    assert_text "キュウリ"
    assert_text "ほうれん草"
    
    # 品種も表示される
    assert_text "桃太郎"
    assert_text "夏すずみ"
    assert_text "一般"
    
    take_screenshot
  end

  test "作物カードがドラッグ可能である" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    
    # 作物カードがドラッグ可能であることを確認
    crop_cards = all(".crop-palette-card")
    assert crop_cards.length > 0, "作物カードが見つかりません"
    
    # 各カードがdraggable属性を持っている
    crop_cards.each do |card|
      assert_equal "true", card[:draggable], "作物カードがドラッグ可能ではありません"
    end
    
    # JavaScriptが読み込まれているか確認
    js_loaded = page.evaluate_script(<<~JS)
      typeof window.initCropPalette === 'function';
    JS
    
    assert js_loaded, "作物パレットのJavaScriptが読み込まれていません"
    
    # ドラッグイベントをシミュレートして、エラーが発生しないことを確認
    drag_event_works = page.evaluate_script(<<~JS)
      (function() {
        try {
          var card = document.querySelector('.crop-palette-card[draggable="true"]');
          if (!card) return false;
          
          // dragstartイベントを発火
          var dragEvent = new DragEvent('dragstart', {
            bubbles: true,
            cancelable: true,
            dataTransfer: new DataTransfer()
          });
          card.dispatchEvent(dragEvent);
          
          return true;
        } catch (e) {
          console.error('Drag event error:', e);
          return false;
        }
      })();
    JS
    
    assert drag_event_works, "ドラッグイベントの発火に失敗しました"
    
    take_screenshot
  end

  test "作物パレットのトグルボタンが複数回クリックされても正常に動作する" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    panel = find("#crop-palette-panel")
    toggle_btn = find("#crop-palette-toggle")
    
    # 複数回クリックして状態が正しく切り替わることを確認
    initial_state = panel[:class].include?("collapsed")
    
    5.times do |i|
      toggle_btn.click
      sleep 0.1 # クリック間隔を空ける
      
      # クリック回数に応じて状態が切り替わる
      expected_collapsed = (i + 1).odd? ? !initial_state : initial_state
      actual_collapsed = panel[:class].include?("collapsed")
      
      assert_equal expected_collapsed, actual_collapsed, 
        "#{i+1}回目のクリック後、期待される状態と異なります (期待: #{expected_collapsed ? '閉じた' : '開いた'}, 実際: #{actual_collapsed ? '閉じた' : '開いた'})"
    end
    
    take_screenshot
  end

  test "作物パレットのイベントリスナーが重複登録されていない" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    assert_selector "#crop-palette-toggle", wait: 10
    
    # イベントリスナーが一度だけ設定されているか確認
    listener_count = page.evaluate_script(<<~JS)
      var toggleBtn = document.getElementById('crop-palette-toggle');
      return toggleBtn ? toggleBtn.dataset.listenerAdded === 'true' : false;
    JS
    
    assert listener_count, "イベントリスナーが正しく設定されていません"
    
    # トグルボタンをクリックして、コンソールログを確認
    toggle_btn = find("#crop-palette-toggle")
    toggle_btn.click
    
    # クリックイベントが1回だけ実行されることを確認
    # （実際のテストでは、複数回のイベント発火を防ぐことができているか確認）
    panel = find("#crop-palette-panel")
    assert panel[:class].include?("collapsed"), "1回目のクリックでドロワーが閉じていません"
    
    take_screenshot
  end

  test "作物パレットがレスポンシブデザインに対応している" do
    visit_results_page
    
    # 作物パレットパネルが存在することを確認
    assert_selector "#crop-palette-panel", wait: 10
    
    # デスクトップサイズでの表示を確認
    page.driver.browser.manage.window.resize_to(1400, 900)
    sleep 0.5
    
    panel = find("#crop-palette-panel")
    panel_style = page.evaluate_script(<<~JS)
      var panel = document.getElementById('crop-palette-panel');
      return {
        width: window.getComputedStyle(panel).width,
        position: window.getComputedStyle(panel).position
      };
    JS
    
    assert_equal "320px", panel_style["width"], "デスクトップサイズで幅が正しくありません"
    assert_equal "fixed", panel_style["position"], "デスクトップサイズで位置が正しくありません"
    
    # モバイルサイズでの表示を確認
    page.driver.browser.manage.window.resize_to(768, 1024)
    sleep 0.5
    
    panel_style_mobile = page.evaluate_script(<<~JS)
      var panel = document.getElementById('crop-palette-panel');
      return {
        width: window.getComputedStyle(panel).width
      };
    JS
    
    assert_equal "280px", panel_style_mobile["width"], "モバイルサイズで幅が正しくありません"
    
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
    
    field2 = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "圃場 2",
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
    
    crop2 = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @crop2.name,
      variety: @crop2.variety,
      agrr_crop_id: @crop2.name
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
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop2,
      area: 50.0,
      start_date: Date.new(2024, 5, 1),
      completion_date: Date.new(2024, 7, 15),
      cultivation_days: 75,
      estimated_cost: 30000.0,
      status: :completed
    )
    
    plan
  end

  def take_screenshot
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    screenshot_path = Rails.root.join("tmp", "screenshots", "crop_palette_drawer_e2e_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end
