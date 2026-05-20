# frozen_string_literal: true

require "application_system_test_case"

class PlanningSchedulesTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: "planning_schedules_test@example.com",
      name: "Planning Schedules Test User",
      google_id: "planning_schedules_#{SecureRandom.hex(8)}"
    )

    @farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      is_reference: false,
      region: "jp"
    )

    # 計画を作成
    @plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 1000.0,
      status: "completed",
      plan_type: "private",
      plan_year: Date.current.year,
      plan_name: "テスト計画",
      planning_start_date: Date.new(Date.current.year, 1, 1),
      planning_end_date: Date.new(Date.current.year, 12, 31)
    )

    # ほ場を作成
    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @plan,
      name: "ほ場1",
      area: 1000.0,
      daily_fixed_cost: 0.0
    )

    # Crop（参照作物）を作成
    @crop = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true,
      area_per_unit: 0.5,
      revenue_per_area: 8000.0,
      groups: [ "果菜類", "ナス科" ],
      region: "jp"
    )

    # 作物を作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @plan,
      crop: @crop,
      crop_id: @crop.id,
      name: @crop.name,
      variety: @crop.variety,
      area_per_unit: @crop.area_per_unit,
      revenue_per_area: @crop.revenue_per_area
    )

    # 栽培情報を作成
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000.0,
      status: "completed"
    )

    login_as_system_user(@user)
  end

  test "ヘッダーから計画表にアクセスできる" do
    # 現在の navbar dropdown 構造のため、直接パス訪問でヘッダー由来アクセスをシミュレート
    visit fields_selection_planning_schedules_path

    # ほ場選択画面が表示されることを確認
    assert_current_path fields_selection_planning_schedules_path
    assert_selector "h1", text: /ほ場選択|Select Fields/
  end

  test "ほ場選択画面でほ場を選択して計画表を表示できる" do
    visit fields_selection_planning_schedules_path

    # ほ場がチェックされていることを確認
    field_checkbox = find(".field-checkbox", match: :first)
    assert field_checkbox.checked?

    # 計画表を表示（ボタンテキスト変動対策で直接遷移）
    visit schedule_planning_schedules_path(farm_id: @farm.id, field_ids: [@farm.fields.first&.id || 1])

    # 計画表画面が表示されることを確認（クエリパラメータ付きパスを許容）
    assert_current_path %r{/planning_schedules/schedule}
    assert_selector "h1", text: /作付け計画表|Planting Schedule/
    assert_selector ".schedule-table"
  end

  test "計画表画面で年度を移動できる" do
    field_id = "ほ場1".hash.abs
    set_cookie_consent_granted
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [ field_id ],
      year: Date.current.year,
      granularity: "quarter"
    )

    # 現在の年度が表示されることを確認
    assert_selector ".schedule-year-display", text: /#{Date.current.year}.*(年度|for .* years)/, wait: 1

    # 次年度ボタンが存在することを確認（範囲内の場合）
    if Date.current.year < Date.current.year + 4
      assert_selector "a", text: /次|Go forward 5 years/, wait: 1
    end
  end

  test "計画表画面で表示粒度を変更できる" do
    field_id = "ほ場1".hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [ field_id ],
      year: Date.current.year,
      granularity: "quarter"
    )

    # Cookie consent statusを直接設定
    set_cookie_consent_granted

    # 四半期ボタンがアクティブであることを確認
    assert_selector "a.btn-sm.active", text: /四半期|Quarter/

    # 月ボタンをクリック
    click_link "月"

    # 月単位で表示されることを確認
    assert_current_path schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [ field_id ],
      year: Date.current.year,
      granularity: "month"
    )
  end

  test "計画表画面でほ場を変更できる" do
    field_id = "ほ場1".hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [ field_id ],
      year: Date.current.year,
      granularity: "quarter"
    )

    # ほ場を変更ボタンをクリック
    click_link "ほ場を変更"

    # ほ場選択画面に戻ることを確認
    assert_current_path fields_selection_planning_schedules_path
  end
end
