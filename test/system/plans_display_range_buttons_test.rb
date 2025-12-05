# frozen_string_literal: true

require "application_system_test_case"

class PlansDisplayRangeButtonsTest < ApplicationSystemTestCase
  setup do
    # テストデータを作成
    @user = User.create!(
      email: 'range_test@example.com',
      name: 'Range Test User',
      google_id: "range_#{SecureRandom.hex(8)}"
    )
    
    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      timezone: "Asia/Tokyo"
    )
    
    @farm = Farm.create!(
      user: @user,
      name: '範囲テスト農場',
      latitude: 35.6812,
      longitude: 139.7671,
      weather_location: @weather_location,
      is_reference: false,
      region: 'jp'
    )
    
    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: 'テスト圃場',
      area: 100.0
    )
    
    @crop = Crop.create!(
      user: @user,
      name: 'テスト作物',
      is_reference: false,
      area_per_unit: 1.0,
      revenue_per_area: 1000.0
    )
    
    # 計画期間を2年間に設定（現在年から翌年まで）
    plan_start_date = Date.current.beginning_of_year
    plan_end_date = Date.new(Date.current.year + 1, 12, 31)
    
    # Private計画を作成
    @private_plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      status: 'completed',
      plan_type: 'private',
      plan_name: '範囲テスト計画',
      planning_start_date: plan_start_date,
      planning_end_date: plan_end_date
    )
    
    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @private_plan,
      field: @field,
      name: @field.name,
      area: @field.area
    )
    
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @private_plan,
      crop: @crop,
      name: @crop.name,
      variety: @crop.variety,
      area_per_unit: @crop.area_per_unit,
      revenue_per_area: @crop.revenue_per_area,
      crop_id: @crop.id
    )
    
    # FieldCultivationを作成
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @private_plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 150.days,
      cultivation_days: 121,
      area: 100.0,
      estimated_cost: 10000.0,
      optimization_result: {
        revenue: 50000.0,
        profit: 40000.0,
        accumulated_gdd: 1500.0
      }
    )
    
    # ユーザーのセッションを作成してログイン
    @session = Session.create_for_user(@user)
  end
  
  test "期間選択ボタンが表示される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # ガントセクションのツールバー内に表示範囲コントロールが存在することを確認
    assert_selector '.plans-gantt-panel', wait: 5
    within '.plans-gantt-panel' do
      assert_selector '.display-range-toolbar', wait: 5
    end
    
    # 開始日・終了日の入力フィールドが存在することを確認
    assert_selector '#display-start-date', wait: 5
    assert_selector '#display-end-date', wait: 5
    
    # 適用ボタンが存在することを確認
    assert_selector '#apply-display-range', wait: 5
    
    # クイック選択ボタン群が存在することを確認
    assert_selector '.display-range-quick-buttons', wait: 5
    assert_selector '[data-display-range-action="month-back"]', wait: 5
    assert_selector '[data-display-range-action="month-forward"]', wait: 5
    assert_selector '[data-display-range-action="range-1year"]', wait: 5
    assert_selector '[data-display-range-action="range-2year"]', wait: 5
    assert_selector '[data-display-range-action="full-range"]', wait: 5
  end

  test "ガントセクションがアクションバー直後に配置される" do
    login_and_visit plan_path(@private_plan, locale: :ja)

    assert_selector '.plans-container', wait: 10
    assert_selector '.plans-gantt-panel', wait: 5

    children_classes = page.evaluate_script(<<~JS)
      Array.from(document.querySelector('.plans-container').children)
        .map(el => el.className || "")
    JS

    gantt_index = children_classes.index { |cls| cls.include?('plans-gantt-panel') }
    assert_equal 2, gantt_index, "ガントセクションはアクションバーとサマリーカード直後に配置される想定です"
  end
  
  test "全体表示ボタンで計画期間全体が表示される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # 初期の日付を取得
    initial_start_date = find('#display-start-date').value
    initial_end_date = find('#display-end-date').value
    
    # 全体表示ボタンをクリック
    find('[data-display-range-action="full-range"]').click
    
    # JavaScriptの実行を待つ
    sleep 1
    
    # 日付が計画期間全体に更新されることを確認
    final_start_date = find('#display-start-date').value
    final_end_date = find('#display-end-date').value
    
    assert_equal @private_plan.planning_start_date.strftime('%Y-%m-%d'), final_start_date
    assert_equal @private_plan.planning_end_date.strftime('%Y-%m-%d'), final_end_date
  end
  
  test "1年ボタンで1年間の範囲が設定される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # 初期の開始日を取得
    initial_start_date = Date.parse(find('#display-start-date').value)
    
    # 1年ボタンをクリック
    find('[data-display-range-action="range-1year"]').click
    
    # JavaScriptの実行を待つ
    sleep 1
    
    # 開始日と終了日を取得
    start_date = Date.parse(find('#display-start-date').value)
    end_date = Date.parse(find('#display-end-date').value)
    
    # 開始日は初期値から変わらない（または計画期間内に制約される）
    assert start_date >= @private_plan.planning_start_date, '開始日は計画開始日以降である必要があります'
    
    # 終了日は開始日から約1年後であることを確認（計画期間を超えない場合は調整される）
    expected_end_date = [start_date + 1.year, @private_plan.planning_end_date].min
    assert_equal expected_end_date, end_date, '終了日は開始日から1年後（または計画終了日）である必要があります'
  end
  
  test "2年ボタンで2年間の範囲が設定される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # 初期の開始日を取得
    initial_start_date = Date.parse(find('#display-start-date').value)
    
    # 2年ボタンをクリック
    find('[data-display-range-action="range-2year"]').click
    
    # JavaScriptの実行を待つ
    sleep 1
    
    # 開始日と終了日を取得
    start_date = Date.parse(find('#display-start-date').value)
    end_date = Date.parse(find('#display-end-date').value)
    
    # 開始日は初期値から変わらない（または計画期間内に制約される）
    assert start_date >= @private_plan.planning_start_date, '開始日は計画開始日以降である必要があります'
    
    # 終了日は開始日から約2年後であることを確認（計画期間を超えない場合は調整される）
    expected_end_date = [start_date + 2.years, @private_plan.planning_end_date].min
    assert_equal expected_end_date, end_date, '終了日は開始日から2年後（または計画終了日）である必要があります'
  end
  
  test "計画期間外への移動が防止される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # 1ヶ月前に移動ボタンを複数回クリック（計画期間外に移動しようとする）
    month_back_button = find('[data-display-range-action="month-back"]')
    20.times do
      month_back_button.click
      sleep 0.3
    end
    
    # JavaScriptの実行を待つ
    sleep 1
    
    # 開始日が計画期間内に制約されていることを確認
    start_date = Date.parse(find('#display-start-date').value)
    end_date = Date.parse(find('#display-end-date').value)
    
    assert start_date >= @private_plan.planning_start_date, '開始日は計画開始日以降である必要があります'
    assert end_date <= @private_plan.planning_end_date, '終了日は計画終了日以前である必要があります'
    assert start_date < end_date, '開始日は終了日より前である必要があります'
  end
  
  test "ガントチャートが再描画される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    
    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10
    
    # ガントチャートコンテナが存在することを確認
    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    
    # 初期状態でSVGが存在することを確認（存在しない場合もあるので、コンテナの存在のみ確認）
    gantt_container = find('#gantt-chart-container', visible: :all)
    initial_data = gantt_container['data-cultivations']
    
    # 全体表示ボタンをクリック
    find('[data-display-range-action="full-range"]').click
    
    # JavaScriptの実行と再描画を待つ
    sleep 2
    
    # ガントチャートコンテナが依然として存在することを確認
    assert_selector '#gantt-chart-container', wait: 5, visible: :all
    
    # データが保持されていることを確認
    final_container = find('#gantt-chart-container', visible: :all)
    final_data = final_container['data-cultivations']
    
    assert_equal initial_data, final_data, 'ガントチャートのデータは保持される必要があります'
  end
  
end

