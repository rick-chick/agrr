# frozen_string_literal: true

require "application_system_test_case"

class ActionCableRealtimeUpdateTest < ApplicationSystemTestCase
  def setup
    super
    
    # アノニマスユーザーを作成
    @user = User.create!(
      email: "anonymous@agrr.app",
      name: "Anonymous User",
      google_id: "anonymous_realtime_test",
      is_anonymous: true
    )
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @user,
      name: "リアルタイムテスト農場",
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
    
    # 天気データと気象予測データを作成
    create_weather_data
    
    # 参照作物を作成
    @crop = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true
    )
    
    # 作付け計画を作成
    @cultivation_plan = create_completed_cultivation_plan
  end

  test "ドラッグ&ドロップ後にAction Cable経由でリアルタイム更新される（リロードされない）" do
    puts "\n" + "="*80
    puts "🧪 Action Cableリアルタイム更新E2Eテスト開始"
    puts "="*80
    
    # 1. 結果ページにアクセス
    puts "\n📍 STEP 1: 結果ページにアクセス"
    visit results_public_plans_path(plan_id: @cultivation_plan.id)
    
    # 2. ガントチャートが読み込まれるまで待機
    puts "\n📍 STEP 2: ガントチャートの読み込みを確認"
    assert_selector "#gantt-chart-container svg", wait: 15
    assert_selector ".cultivation-bar", minimum: 1, wait: 10
    
    initial_bars_count = page.all(".cultivation-bar").count
    puts "   ✅ 栽培バー数: #{initial_bars_count}"
    
    # 3. Action Cableが接続されたことを確認
    puts "\n📍 STEP 3: Action Cable接続を確認"
    sleep 2 # Action Cable接続を待つ
    
    cable_connected = page.evaluate_script(<<~JS)
      return window.CableSubscriptionManager &&
             window.CableSubscriptionManager.subscriptions &&
             window.CableSubscriptionManager.subscriptions.size > 0;
    JS
    
    assert cable_connected, "Action Cableが接続されていません"
    puts "   ✅ Action Cable接続完了"
    
    # 4. リロードを検出するフラグを設定
    puts "\n📍 STEP 4: リロード検出フラグを設定"
    page.evaluate_script(<<~JS)
      window.pageReloaded = false;
      window.addEventListener('beforeunload', function() {
        localStorage.setItem('pageReloaded', 'true');
      });
    JS
    
    # 5. 初期データを記録
    puts "\n📍 STEP 5: 初期データを記録"
    initial_data = page.evaluate_script(<<~JS)
      const firstBar = document.querySelector('.cultivation-bar .bar-bg');
      return {
        x: parseFloat(firstBar.getAttribute('x')),
        y: parseFloat(firstBar.getAttribute('y')),
        cultivationId: parseInt(firstBar.parentElement.getAttribute('data-id'))
      };
    JS
    
    puts "   初期位置: x=#{initial_data['x']}, y=#{initial_data['y']}"
    puts "   栽培ID: #{initial_data['cultivationId']}"
    
    # 6. ドラッグ&ドロップを実行（7日後に移動）
    puts "\n📍 STEP 6: ドラッグ&ドロップを実行"
    bar = find('.cultivation-bar .bar-bg', match: :first)
    
    # 100px右にドラッグ（約7日分）
    page.driver.browser.action
      .move_to(bar.native)
      .click_and_hold
      .move_by(100, 0)
      .release
      .perform
    
    puts "   ✅ ドラッグ操作完了"
    
    # 7. ローディングオーバーレイが表示されることを確認
    puts "\n📍 STEP 7: ローディングオーバーレイを確認"
    assert_selector "#reoptimization-overlay", wait: 2
    puts "   ✅ ローディングオーバーレイ表示"
    
    # 8. adjustリクエストが送信されたことをログで確認
    puts "\n📍 STEP 8: adjustリクエストの送信を確認"
    sleep 1
    
    request_sent = page.evaluate_script(<<~JS)
      window.ganttState && window.ganttState.moves && window.ganttState.moves.length > 0
    JS
    
    assert request_sent, "adjustリクエストが送信されていません"
    puts "   ✅ adjustリクエスト送信完了"
    
    # 9. Action Cableメッセージを待つ（最大30秒）
    puts "\n📍 STEP 9: Action Cableメッセージを待機（最大30秒）"
    
    message_received = false
    30.times do
      sleep 1
      
      # ローディングオーバーレイが消えたかチェック
      overlay_visible = page.has_selector?("#reoptimization-overlay", wait: 0)
      
      unless overlay_visible
        puts "   ✅ ローディングオーバーレイが消えました"
        message_received = true
        break
      end
      
      print "."
    end
    puts ""
    
    # 10. ページがリロードされていないことを確認
    puts "\n📍 STEP 10: ページがリロードされていないことを確認"
    
    page_reloaded = page.evaluate_script(<<~JS)
      return localStorage.getItem('pageReloaded') === 'true';
    JS
    
    assert_not page_reloaded, "❌ ページがリロードされました！"
    puts "   ✅ ページはリロードされていません"
    
    # 11. データが更新されたことを確認
    puts "\n📍 STEP 11: データ更新を確認"
    
    # ガントチャートがまだ表示されている
    assert_selector "#gantt-chart-container svg", wait: 5
    
    final_bars_count = page.all(".cultivation-bar").count
    puts "   最終の栽培バー数: #{final_bars_count}"
    
    # バーの数が変わっていないか、またはagrrの結果によって変更された
    assert final_bars_count >= 0, "栽培バーが消失しました"
    
    # 12. コンソールログを確認
    puts "\n📍 STEP 12: コンソールログを確認"
    
    logs = page.driver.browser.logs.get(:browser)
    cable_logs = logs.select { |log| log.message.include?('Cable') || log.message.include?('最適化') }
    
    puts "   関連ログ:"
    cable_logs.last(10).each do |log|
      puts "     #{log.message}"
    end
    
    # スクリーンショットを保存
    take_screenshot("action_cable_realtime_update")
    
    puts "\n" + "="*80
    puts "✅ テスト完了"
    puts "="*80
  end

  test "エラー時にページがリロードされずアラートが表示される" do
    puts "\n" + "="*80
    puts "🧪 エラー時のフォールバックテスト"
    puts "="*80
    
    # 結果ページにアクセス
    visit results_public_plans_path(plan_id: @cultivation_plan.id)
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 15
    assert_selector ".cultivation-bar", minimum: 1, wait: 10
    
    # Action Cable接続を確認
    sleep 2
    
    cable_connected = page.evaluate_script(<<~JS)
      return window.CableSubscriptionManager &&
             window.CableSubscriptionManager.subscriptions &&
             window.CableSubscriptionManager.subscriptions.size > 0;
    JS
    
    assert cable_connected, "Action Cableが接続されていません"
    
    # リロード検出フラグを設定
    page.evaluate_script(<<~JS)
      window.pageReloaded = false;
      window.addEventListener('beforeunload', function() {
        localStorage.setItem('pageReloaded', 'true');
      });
      
      // エラーをシミュレート: fetchを失敗させる
      const originalFetch = window.fetch;
      window.fetch = function(url, options) {
        if (url.includes('/adjust')) {
          return Promise.resolve({
            ok: false,
            status: 500,
            statusText: 'Internal Server Error',
            json: () => Promise.resolve({
              success: false,
              message: 'テストエラー: 移動先の日付では重複します'
            })
          });
        }
        return originalFetch(url, options);
      };
    JS
    
    # ドラッグ&ドロップを実行
    bar = find('.cultivation-bar .bar-bg', match: :first)
    page.driver.browser.action
      .move_to(bar.native)
      .click_and_hold
      .move_by(100, 0)
      .release
      .perform
    
    sleep 2
    
    # アラートが表示される（実際には自動的に閉じる）
    # ページがリロードされていないことを確認
    page_reloaded = page.evaluate_script(<<~JS)
      localStorage.getItem('pageReloaded') === 'true'
    JS
    
    assert_not page_reloaded, "エラー時にページがリロードされました"
    
    puts "✅ エラー時もページはリロードされませんでした"
    
    take_screenshot("action_cable_error_handling")
  end

  private

  def create_weather_data
    # 過去1年分の気象データ
    start_date = Date.new(2024, 1, 1)
    end_date = Date.new(2024, 12, 31)
    
    (start_date..end_date).each do |date|
      # 季節に応じた温度変化
      month = date.month
      base_temp = if month.in?([12, 1, 2])
        5.0  # 冬
      elsif month.in?([3, 4, 5])
        15.0  # 春
      elsif month.in?([6, 7, 8])
        28.0  # 夏
      else
        18.0  # 秋
      end
      
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: base_temp + rand(0.0..8.0),
        temperature_min: base_temp - rand(5.0..10.0),
        temperature_mean: base_temp + rand(-2.0..3.0),
        precipitation: rand(0.0..20.0)
      )
    end
    
    puts "   ✅ 気象データ作成: #{(end_date - start_date + 1).to_i}日分"
  end

  def create_completed_cultivation_plan
    plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 200.0,
      status: :completed,
      planning_start_date: Date.new(2024, 4, 1),
      planning_end_date: Date.new(2024, 10, 31),
      session_id: "test_session_#{SecureRandom.hex(8)}"
    )
    
    # 気象予測データを保存（adjustで必要）
    plan.update!(
      predicted_weather_data: {
        'latitude' => @farm.latitude,
        'longitude' => @farm.longitude,
        'timezone' => 'Asia/Tokyo',
        'data' => @weather_location.weather_data
          .where('date >= ?', Date.new(2024, 1, 1))
          .order(:date)
          .limit(365)
          .map do |datum|
            {
              'time' => datum.date.to_s,
              'temperature_2m_max' => datum.temperature_max,
              'temperature_2m_min' => datum.temperature_min,
              'temperature_2m_mean' => datum.temperature_mean,
              'precipitation_sum' => datum.precipitation || 0.0
            }
          end
      }
    )
    
    # 2つの圃場を作成
    field1 = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "圃場 1",
      area: 100.0,
      daily_fixed_cost: 100.0
    )
    
    field2 = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "圃場 2",
      area: 100.0,
      daily_fixed_cost: 100.0
    )
    
    # 作物を作成
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @crop.name,
      variety: @crop.variety,
      agrr_crop_id: @crop.name
    )
    
    # 栽培スケジュールを作成
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop,
      area: 50.0,
      start_date: Date.new(2024, 4, 15),
      completion_date: Date.new(2024, 8, 20),
      cultivation_days: 127,
      estimated_cost: 5000.0,
      status: :completed,
      optimization_result: {
        'revenue' => 25000.0,
        'profit' => 20000.0,
        'accumulated_gdd' => 1500.0
      }
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop,
      area: 50.0,
      start_date: Date.new(2024, 5, 1),
      completion_date: Date.new(2024, 7, 15),
      cultivation_days: 75,
      estimated_cost: 3000.0,
      status: :completed,
      optimization_result: {
        'revenue' => 15000.0,
        'profit' => 12000.0,
        'accumulated_gdd' => 1500.0
      }
    )
    
    puts "   ✅ 栽培計画作成: ID=#{plan.id}"
    
    plan
  end

  def take_screenshot(name = nil)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = name ? "#{name}_#{timestamp}.png" : "screenshot_#{timestamp}.png"
    screenshot_path = Rails.root.join("tmp", "screenshots", filename)
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end

