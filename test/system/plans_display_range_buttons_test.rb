# frozen_string_literal: true

require "application_system_test_case"

class PlansDisplayRangeButtonsTest < ApplicationSystemTestCase
  setup do
    # 一意の座標を生成（WeatherLocationの一意性バリデーションとの衝突を回避）
    @lat = 35.0 + SecureRandom.random_number * 10
    @lon = 139.0 + SecureRandom.random_number * 10

    # テストデータを作成
    @user = User.create!(
      email: "range_test@example.com",
      name: "Range Test User",
      google_id: "range_#{SecureRandom.hex(8)}"
    )

    @weather_location = WeatherLocation.create!(
      latitude: @lat,
      longitude: @lon,
      timezone: "Asia/Tokyo"
    )

    @farm = Farm.create!(
      user: @user,
      name: "範囲テスト農場",
      latitude: @lat,
      longitude: @lon,
      weather_location: @weather_location,
      is_reference: false,
      region: "jp"
    )

    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: "テスト圃場",
      area: 100.0
    )

    @crop = Crop.create!(
      user: @user,
      name: "テスト作物",
      is_reference: false,
      area_per_unit: 1.0,
      revenue_per_area: 1000.0
    )

    # 計画期間を1年間に設定（現在年）
    plan_start_date = Date.current.beginning_of_year
    plan_end_date = Date.new(Date.current.year, 12, 31)

    # Private計画を作成
    @private_plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      status: "completed",
      plan_type: "private",
      plan_name: "範囲テスト計画",
      planning_start_date: plan_start_date,
      planning_end_date: plan_end_date
    )

    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @private_plan,
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
    login_and_visit_with_consent_fast plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 2

    # ガントセクションのツールバー内に表示範囲コントロールが存在することを確認
    assert_selector ".plans-gantt-panel", wait: 1
    within ".plans-gantt-panel" do
      assert_selector ".display-range-toolbar", wait: 0
    end

    # 開始日・終了日の入力フィールドが存在することを確認
    assert_selector "#display-start-date", wait: 0
    assert_selector "#display-end-date", wait: 0

    # 適用ボタンが存在することを確認
    assert_selector "#apply-display-range", wait: 0

    # クイック選択ボタン群が存在することを確認
    assert_selector ".display-range-quick-buttons", wait: 0
    assert_selector '[data-display-range-action="month-back"]', wait: 0
    assert_selector '[data-display-range-action="month-forward"]', wait: 0
    assert_selector '[data-display-range-action="range-1year"]', wait: 0
    assert_selector '[data-display-range-action="range-2year"]', wait: 0
    assert_selector '[data-display-range-action="full-range"]', wait: 0
  end

  test "ガントセクションがアクションバー直後に配置される" do
    login_and_visit_with_consent_fast plan_path(@private_plan, locale: :ja)

    assert_selector ".plans-container", wait: 2
    assert_selector ".plans-gantt-panel", wait: 2

    children_classes = page.evaluate_script(<<~JS)
      Array.from(document.querySelector('.plans-container').children)
        .map(el => el.className || "")
    JS

    gantt_index = children_classes.index { |cls| cls.include?("plans-gantt-panel") }
    assert_equal 2, gantt_index, "ガントセクションはアクションバーとサマリーカード直後に配置される想定です"
  end

  test "全体表示ボタンで計画期間全体が表示される" do
    login_and_visit_with_consent plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 3

    # 全体表示ボタンをクリック
    find('[data-display-range-action="full-range"]').click

    # JavaScriptの実行と日付更新を待つ
    find("#display-start-date", wait: 2)

    # 日付が計画期間全体に更新されることを確認
    final_start_date = find("#display-start-date").value
    final_end_date = find("#display-end-date").value

    assert_equal @private_plan.planning_start_date.strftime("%Y-%m-%d"), final_start_date
    assert_equal @private_plan.planning_end_date.strftime("%Y-%m-%d"), final_end_date
  end

  test "1年ボタンで1年間の範囲が設定される" do
    login_and_visit_with_consent plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 3

    # 1年ボタンをクリック
    find('[data-display-range-action="range-1year"]').click

    # JavaScriptの実行と日付更新を待つ
    find("#display-start-date", wait: 2)

    # 開始日と終了日を取得
    start_date = Date.parse(find("#display-start-date").value)
    end_date = Date.parse(find("#display-end-date").value)

    # 開始日は計画開始日以降であること
    assert start_date >= @private_plan.planning_start_date, "開始日は計画開始日以降である必要があります"

    # 終了日は開始日から約1年後であることを確認（計画範囲制約は削除済み）
    expected_end_date = start_date + 1.year
    assert_equal expected_end_date, end_date, "終了日は開始日から1年後である必要があります"
  end

  test "2年ボタンで2年間の範囲が設定される" do
    login_and_visit_with_consent plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 3

    # 2年ボタンをクリック
    find('[data-display-range-action="range-2year"]').click

    # JavaScriptの実行と日付更新を待つ
    find("#display-start-date", wait: 2)

    # 開始日と終了日を取得
    start_date = Date.parse(find("#display-start-date").value)
    end_date = Date.parse(find("#display-end-date").value)

    # 開始日は計画開始日以降であること
    assert start_date >= @private_plan.planning_start_date, "開始日は計画開始日以降である必要があります"

    # 終了日は開始日から約2年後であることを確認（計画範囲制約は削除済み）
    expected_end_date = start_date + 2.years
    assert_equal expected_end_date, end_date, "終了日は開始日から2年後である必要があります"
  end

  test "月移動ボタンで表示範囲がシフトする" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    dismiss_cookie_consent

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 3

    # 1ヶ月前に移動ボタンを複数回クリックして範囲がシフトすることを確認
    month_back_button = find('[data-display-range-action="month-back"]')
    3.times do
      month_back_button.click
    end

    # JavaScriptの実行と日付更新を待つ
    find("#display-start-date", wait: 3)

    # 開始日が終了日より前であることを確認
    start_date = Date.parse(find("#display-start-date").value)
    end_date = Date.parse(find("#display-end-date").value)

    assert start_date < end_date, "開始日は終了日より前である必要があります"
  end

  test "ガントチャートが再描画される" do
    login_and_visit_with_consent plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector "h1", text: /計画/, wait: 3

    # ガントチャートコンテナが存在することを確認
    assert_selector "#gantt-chart-container", wait: 5, visible: :all

    # 初期状態でSVGが存在することを確認（存在しない場合もあるので、コンテナの存在のみ確認）
    gantt_container = find("#gantt-chart-container", visible: :all)
    initial_data = gantt_container["data-cultivations"]

    # 全体表示ボタンをクリック
    find('[data-display-range-action="full-range"]').click

    # JavaScriptの実行と再描画を待つ
    find("#gantt-chart-container", wait: 3, visible: :all)

    # ガントチャートコンテナが依然として存在することを確認
    assert_selector "#gantt-chart-container", wait: 3, visible: :all

    # データが保持されていることを確認（JSONをパースして本質的なフィールドのみ比較）
    final_container = find("#gantt-chart-container", visible: :all)
    final_data = final_container["data-cultivations"]

    initial_parsed = JSON.parse(initial_data)
    final_parsed = JSON.parse(final_data)

    assert_equal initial_parsed.map { |d| d["id"] }, final_parsed.map { |d| d["id"] }, "ガントチャートのデータIDは保持される必要があります"
    assert_equal initial_parsed.map { |d| d["start_date"] }, final_parsed.map { |d| d["start_date"] }, "開始日は保持される必要があります"
    assert_equal initial_parsed.map { |d| d["completion_date"] }, final_parsed.map { |d| d["completion_date"] }, "終了日は保持される必要があります"
  end

  private

  # login_and_visitと違い、root_pathアクセス後にlocalStorageにcookie同意を設定し、
  # その後に目標URLにアクセスするため、cookie consentカードが表示されない
  def login_and_visit_with_consent(url)
    visit root_path(locale: :ja)
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: @session.session_id,
      path: "/"
    )
    # rootページでlocalStorageに同意ステータスを設定（Stimulus connect前に設定される）
    set_cookie_consent_granted
    visit url
  end

  # /upヘルスチェックでドメインを確立（root_pathより軽量）・cookie同意をlocalStorageに設定
  def login_and_visit_with_consent_fast(url)
    visit rails_health_check_path
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: @session.session_id,
      path: "/"
    )
    set_cookie_consent_granted
    visit url
  end
end
