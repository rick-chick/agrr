# frozen_string_literal: true

require "application_system_test_case"

class GanttDragDropE2eTest < ApplicationSystemTestCase
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
      is_reference: true
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
      is_reference: true
    )
    
    @crop2 = Crop.create!(
      name: "キュウリ",
      variety: "夏すずみ",
      is_reference: true
    )
    
    # 作付け計画を作成
    @cultivation_plan = create_completed_cultivation_plan
  end

  test "ガントチャートのドラッグ&ドロップ機能が動作する" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container", wait: 10
    
    # SVG要素が生成されている
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # 栽培バーが存在する
    assert_selector ".cultivation-bar", minimum: 1, wait: 10
    
    # バーにドラッグ可能なカーソルが設定されている
    first_bar = first(".cultivation-bar .bar-bg")
    assert first_bar.present?
    
    # カーソルスタイルを確認
    cursor_style = page.evaluate_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      return bar ? window.getComputedStyle(bar).cursor : null;
    JS
    
    assert_equal "grab", cursor_style, "バーにgrabカーソルが設定されていません"
    
    # ドラッグ操作をシミュレート
    page.execute_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      
      // ドラッグ開始
      const mousedownEvent = new MouseEvent('mousedown', {
        clientX: 100,
        clientY: 100,
        bubbles: true,
        cancelable: true
      });
      bar.dispatchEvent(mousedownEvent);
      
      // ドラッグ移動
      const mousemoveEvent = new MouseEvent('mousemove', {
        clientX: 200,
        clientY: 100,
        bubbles: true,
        cancelable: true
      });
      document.dispatchEvent(mousemoveEvent);
      
      // ドラッグ終了
      const mouseupEvent = new MouseEvent('mouseup', {
        clientX: 200,
        clientY: 100,
        bubbles: true,
        cancelable: true
      });
      document.dispatchEvent(mouseupEvent);
    JS
    
    # ドラッグ状態の視覚的フィードバックを確認
    opacity = page.evaluate_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      return bar ? bar.getAttribute('opacity') : null;
    JS
    
    stroke_width = page.evaluate_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      return bar ? bar.getAttribute('stroke-width') : null;
    JS
    
    # ドラッグ後の状態を確認
    assert_equal "0.95", opacity, "ドラッグ後に透明度が元に戻っていません"
    assert_equal "2.5", stroke_width, "ドラッグ後に線幅が元に戻っていません"
    
    # 削除ボタンが存在する
    assert_selector ".delete-btn", minimum: 1, wait: 5
    
    # 再最適化ボタンが表示される
    # 自動再最適化のため、手動ボタンは表示されない
    # 自動再最適化のため、手動ボタンは表示されない
    
    take_screenshot
  end

  test "削除ボタンが動作する" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 10
    assert_selector ".cultivation-bar", minimum: 1, wait: 10
    assert_selector ".delete-btn", minimum: 1, wait: 5
    
    # 削除ボタンをクリック
    first(".delete-btn").click
    
    # 確認ダイアログが表示される（JavaScriptのconfirm）
    # 実際のダイアログはCapybaraでは確認できないため、
    # クリックイベントが正しく設定されているか確認
    click_event_set = page.evaluate_script(<<~JS)
      const deleteBtn = document.querySelector('.delete-btn');
      return deleteBtn ? deleteBtn.onclick !== null : false;
    JS
    
    assert click_event_set, "削除ボタンにクリックイベントが設定されていません"
    
    take_screenshot
  end

  test "右クリック削除が動作する" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 10
    assert_selector ".cultivation-bar", minimum: 1, wait: 10
    
    # 右クリックイベントをシミュレート
    page.execute_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      const event = new MouseEvent('contextmenu', {
        bubbles: true,
        cancelable: true
      });
      bar.dispatchEvent(event);
    JS
    
    # 右クリックイベントが正しく設定されているか確認
    contextmenu_event_set = page.evaluate_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      return bar ? bar.oncontextmenu !== null : false;
    JS
    
    assert contextmenu_event_set, "右クリックイベントが設定されていません"
    
    take_screenshot
  end

  test "再最適化ボタンが正しく動作する" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container", wait: 10
    
    # 再最適化ボタンが表示される
    # 自動再最適化のため、手動ボタンは表示されない
    # 自動再最適化のため、手動ボタンは表示されない
    
    # 初期状態では無効
    button_disabled = page.evaluate_script(<<~JS)
      // 自動再最適化のため、手動ボタンは存在しない
      return btn ? btn.disabled : null;
    JS
    
    assert button_disabled, "再最適化ボタンが初期状態で有効になっています"
    
    # ドラッグ操作をシミュレートして移動履歴を作成
    page.execute_script(<<~JS)
      const bar = document.querySelector('.cultivation-bar .bar-bg');
      
      // ドラッグ開始
      const mousedownEvent = new MouseEvent('mousedown', {
        clientX: 100,
        clientY: 100,
        bubbles: true,
        cancelable: true
      });
      bar.dispatchEvent(mousedownEvent);
      
      // ドラッグ移動
      const mousemoveEvent = new MouseEvent('mousemove', {
        clientX: 200,
        clientY: 150,
        bubbles: true,
        cancelable: true
      });
      document.dispatchEvent(mousemoveEvent);
      
      // ドラッグ終了
      const mouseupEvent = new MouseEvent('mouseup', {
        clientX: 200,
        clientY: 150,
        bubbles: true,
        cancelable: true
      });
      document.dispatchEvent(mouseupEvent);
    JS
    
    # 移動履歴が記録されているか確認
    moves_count = page.evaluate_script(<<~JS)
      return window.ganttState ? window.ganttState.moves.length : 0;
    JS
    
    assert moves_count > 0, "移動履歴が記録されていません"
    
    # 再最適化ボタンが有効になる
    button_disabled_after = page.evaluate_script(<<~JS)
      // 自動再最適化のため、手動ボタンは存在しない
      return btn ? btn.disabled : null;
    JS
    
    assert_not button_disabled_after, "移動後に再最適化ボタンが有効になっていません"
    
    take_screenshot
  end

  private

  def visit_results_page
    # セッションに計画IDを設定
    page.driver.browser.manage.add_cookie(
      name: 'cultivation_plan_id',
      value: @cultivation_plan.id.to_s
    )
    
    visit results_public_plans_path
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
    screenshot_path = Rails.root.join("tmp", "screenshots", "gantt_drag_drop_e2e_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end
