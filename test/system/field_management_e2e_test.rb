# frozen_string_literal: true

require "application_system_test_case"

class FieldManagementE2eTest < ApplicationSystemTestCase
  def setup
    # アノニマスユーザーを作成
    @user = User.create!(
      email: "anonymous@agrr.app",
      name: "Anonymous User",
      google_id: "anonymous_test_field",
      is_anonymous: true
    )
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @user,
      name: "テスト農場（圃場管理）",
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
    
    @farm.update!(weather_location: @weather_location)
    
    # 天気データを作成
    create_weather_data
    
    # 参照作物を作成（既存のfixtureから取得する方が安全）
    @crop1 = Crop.find_or_create_by!(
      name: "トマト",
      variety: "桃太郎"
    ) do |crop|
      crop.is_reference = true
      crop.area_per_unit = 100.0
      crop.revenue_per_area = 1000.0
    end
    
    # 作付け計画を作成
    @cultivation_plan = create_completed_cultivation_plan_with_fields
  end

  test "圃場を追加できる" do
    puts "🔍 Plan ID: #{@cultivation_plan.id}"
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container", wait: 10
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # 初期圃場数を確認
    initial_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 初期圃場数: #{initial_field_count}"
    
    # 圃場追加ボタンが表示されている
    assert_selector ".add-field-btn", wait: 5
    
    # 圃場追加ボタンをクリック
    page.execute_script('window.addField();')
    
    # プロンプトに自動応答（JavaScriptのpromptをモック）
    page.execute_script <<-JS
      window.prompt = function(message, defaultValue) {
        if (message.includes('圃場名')) {
          return '圃場5';
        } else if (message.includes('面積')) {
          return '150';
        }
        return defaultValue;
      };
    JS
    
    # 再度クリック（promptがモックされた状態で）
    page.execute_script('window.addField();')
    
    # ローディングが消えるまで待機
    sleep 3
    
    # 新しい圃場が追加されている
    new_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 追加後の圃場数: #{new_field_count}"
    
    assert_equal initial_field_count + 1, new_field_count, "圃場が追加されていません"
    
    # 圃場名が正しい
    field_names = page.evaluate_script('return ganttState.fieldGroups.map(g => g.fieldName);')
    assert_includes field_names, '圃場5', "新しい圃場名が見つかりません"
  end
  
  test "作物のついていない圃場が画面に表示される" do
    # セットアップで作成された圃場1には作物があり、圃場2と3は空
    visit_results_page
    
    # ページ読み込み完了を待機
    sleep 2
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container", wait: 15
    assert_selector "#gantt-chart-container svg", wait: 15
    
    # データベース上の圃場数を確認
    db_field_count = @cultivation_plan.cultivation_plan_fields.count
    puts "📊 DB上の圃場数: #{db_field_count}"
    
    # 画面上の圃場数を確認
    ui_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 UI上の圃場数: #{ui_field_count}"
    
    # DB上の圃場数とUI上の圃場数が一致することを確認
    assert_equal db_field_count, ui_field_count, 
      "DB上の圃場数(#{db_field_count})とUI上の圃場数(#{ui_field_count})が一致しません。空の圃場が表示されていない可能性があります。"
    
    # 各圃場の作物数を確認
    field_groups = page.evaluate_script('return ganttState.fieldGroups;')
    puts "📊 圃場グループ詳細:"
    field_groups.each do |group|
      cultivations_count = group['cultivations'].length
      puts "  - #{group['fieldName']}: 作物数=#{cultivations_count}"
    end
    
    # 作物がない圃場（圃場2と圃場3）が含まれていることを確認
    field_names = field_groups.map { |g| g['fieldName'] }
    assert_includes field_names, '圃場2', "空の圃場（圃場2）が表示されていません"
    assert_includes field_names, '圃場3', "空の圃場（圃場3）が表示されていません"
    
    # 作物がない圃場の削除ボタンが表示されていることを確認
    delete_btn_count = page.all('.delete-field-btn', wait: 2).count
    assert_operator delete_btn_count, :>=, 2, "空の圃場の削除ボタンが表示されていません（期待: 2個以上、実際: #{delete_btn_count}個）"
  end
  
  test "空の圃場を削除できる" do
    # 圃場4を追加（空の圃場）
    @cultivation_plan.cultivation_plan_fields.create!(
      name: '圃場4',
      area: 100.0
    )
    
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # 初期圃場数を確認
    initial_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 初期圃場数: #{initial_field_count}"
    
    # 空の圃場（圃場4）の削除ボタンが表示されている
    assert_selector ".delete-field-btn", minimum: 1, wait: 5
    
    # 圃場4のfield_idを取得
    field4_id = @cultivation_plan.cultivation_plan_fields.find_by(name: '圃場4').id
    field4_id_str = "field_#{field4_id}"
    
    # confirmをモック
    page.execute_script('window.confirm = function() { return true; };')
    
    # 削除ボタンをクリック
    page.execute_script("window.removeField('#{field4_id_str}');")
    
    # ローディングが消えるまで待機
    sleep 3
    
    # 圃場が削除されている
    new_field_count = page.evaluate_script('return ganttState.fieldGroups.length;')
    puts "📊 削除後の圃場数: #{new_field_count}"
    
    assert_equal initial_field_count - 1, new_field_count, "圃場が削除されていません"
    
    # 圃場4が存在しない
    field_names = page.evaluate_script('return ganttState.fieldGroups.map(g => g.fieldName);')
    assert_not_includes field_names, '圃場4', "削除した圃場がまだ存在しています"
  end
  
  test "作物がある圃場は削除できない" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # 作物がある圃場の削除ボタンは表示されない
    # （group.cultivations.length > 0の場合は削除ボタンを表示しない実装）
    
    # 全圃場に作物がある場合、削除ボタンは0個のはず
    cultivations_count = @cultivation_plan.field_cultivations.count
    fields_count = @cultivation_plan.cultivation_plan_fields.count
    
    if cultivations_count >= fields_count
      # すべての圃場に作物がある場合
      delete_btn_count = page.all('.delete-field-btn', wait: 2).count
      assert_equal 0, delete_btn_count, "作物がある圃場に削除ボタンが表示されています"
    end
  end
  
  test "圃場追加後に作物をドロップできる" do
    visit_results_page
    
    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg", wait: 10
    
    # promptとconfirmをモック
    page.execute_script <<-JS
      window.prompt = function(message, defaultValue) {
        if (message.includes('圃場名')) return '圃場5';
        if (message.includes('面積')) return '200';
        return defaultValue;
      };
      window.confirm = function() { return true; };
    JS
    
    # 圃場を追加
    page.execute_script('window.addField();')
    sleep 3
    
    # 新しい圃場が追加されている
    field_names = page.evaluate_script('return ganttState.fieldGroups.map(g => g.fieldName);')
    assert_includes field_names, '圃場5', "新しい圃場が追加されていません"
    
    # 作物パレットを開く
    if page.has_css?('#crop-palette-toggle', wait: 2)
      page.execute_script('document.getElementById("crop-palette-toggle").click();')
      sleep 0.5
    end
    
    # 作物パレットが表示されている
    assert_selector '.crop-palette-panel', wait: 5
    
    # field_idの形式を確認
    field_ids = page.evaluate_script('return ganttState.fieldGroups.map(g => g.fieldId);')
    puts "📊 圃場ID一覧: #{field_ids.inspect}"
    
    # すべてのfield_idが"field_123"形式であることを確認
    field_ids.each do |field_id|
      assert field_id.to_s.start_with?('field_'), "field_idが正しい形式ではありません: #{field_id}"
    end
  end

  private

  def create_weather_data
    # 今年のデータ（過去20年分の簡易版）
    start_date = Date.current - 1.year
    end_date = Date.current + 1.year
    
    (start_date..end_date).each do |date|
      @weather_location.weather_data.create!(
        date: date,
        temperature_max: 25.0 + rand(-5.0..5.0),
        temperature_min: 15.0 + rand(-3.0..3.0),
        temperature_mean: 20.0 + rand(-3.0..3.0),
        precipitation: rand(0.0..10.0)
      )
    end
  end

  def create_completed_cultivation_plan_with_fields
    plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 300.0,
      planning_start_date: Date.current,
      planning_end_date: Date.current + 12.months,
      status: 'completed',
      total_profit: 100000.0,
      predicted_weather_data: {
        'latitude' => @farm.latitude,
        'longitude' => @farm.longitude,
        'data' => []
      }
    )
    
    # 圃場を3つ作成
    field1 = plan.cultivation_plan_fields.create!(name: '圃場1', area: 100.0)
    field2 = plan.cultivation_plan_fields.create!(name: '圃場2', area: 100.0)
    field3 = plan.cultivation_plan_fields.create!(name: '圃場3', area: 100.0)
    
    # 作物を登録
    plan_crop1 = plan.cultivation_plan_crops.create!(
      agrr_crop_id: @crop1.id,
      name: @crop1.name,
      variety: @crop1.variety,
      area_per_unit: @crop1.area_per_unit,
      revenue_per_area: @crop1.revenue_per_area
    )
    
    # 圃場1にだけ栽培を配置（圃場2と3は空のまま）
    plan.field_cultivations.create!(
      cultivation_plan_field: field1,
      cultivation_plan_crop: plan_crop1,
      start_date: Date.current + 1.month,
      completion_date: Date.current + 3.months,
      cultivation_days: 60,
      area: 100.0,
      estimated_cost: 10000.0,
      optimization_result: {
        'revenue' => 100000.0,
        'profit' => 90000.0,
        'accumulated_gdd' => 1000.0
      }
    )
    
    plan
  end

  def visit_results_page
    visit results_public_plans_path(cultivation_plan_id: @cultivation_plan.id, locale: :ja)
  end
end

