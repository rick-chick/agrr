# frozen_string_literal: true

require "application_system_test_case"

class PlanningSchedulesTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: 'planning_schedules_test@example.com',
      name: 'Planning Schedules Test User',
      google_id: "planning_schedules_#{SecureRandom.hex(8)}"
    )
    
    @farm = Farm.create!(
      user: @user,
      name: 'テスト農場',
      latitude: 35.6812,
      longitude: 139.7671,
      is_reference: false,
      region: 'jp'
    )
    
    # 計画を作成
    @plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 1000.0,
      status: 'completed',
      plan_type: 'private',
      plan_year: Date.current.year,
      plan_name: 'テスト計画',
      planning_start_date: Date.new(Date.current.year, 1, 1),
      planning_end_date: Date.new(Date.current.year, 12, 31)
    )
    
    # ほ場を作成
    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @plan,
      name: 'ほ場1',
      area: 1000.0,
      daily_fixed_cost: 0.0
    )
    
    # 作物を作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @plan,
      name: 'トマト',
      area_per_unit: 1.0,
      revenue_per_area: 1000.0
    )
    
    # 栽培情報を作成
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000.0,
      status: 'completed'
    )
    
    login_as_system_user(@user)
  end

  test "ヘッダーから計画表にアクセスできる" do
    visit root_path
    
    # ヘッダーのリンクを確認
    assert_selector 'a.nav-link', text: /計画表/
    
    # 計画表リンクをクリック
    click_link '計画表', match: :first
    
    # ほ場選択画面が表示されることを確認
    assert_current_path fields_selection_planning_schedules_path
    assert_selector 'h1', text: /ほ場選択/
  end

  test "ほ場選択画面で農場を選択できる" do
    visit fields_selection_planning_schedules_path
    
    # 農場選択ドロップダウンが表示されることを確認
    assert_selector 'select[name="farm_id"]'
    
    # ほ場が表示されることを確認
    assert_selector '.field-checkbox', text: /ほ場1/
  end

  test "ほ場選択画面でほ場を選択して計画表を表示できる" do
    visit fields_selection_planning_schedules_path
    
    # ほ場がチェックされていることを確認
    field_checkbox = find('.field-checkbox', match: :first)
    assert field_checkbox.checked?
    
    # 計画表を表示ボタンをクリック
    click_button '選択したほ場で計画表を表示'
    
    # 計画表画面が表示されることを確認
    assert_current_path schedule_planning_schedules_path
    assert_selector 'h1', text: /作付け計画表/
    assert_selector '.schedule-table'
  end

  test "計画表画面で年度を移動できる" do
    field_id = 'ほ場1'.hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    # 現在の年度が表示されることを確認
    assert_selector '.schedule-year-display', text: /#{Date.current.year}年度/
    
    # 次年度ボタンが存在することを確認（範囲内の場合）
    if Date.current.year < Date.current.year + 4
      assert_selector 'a', text: /次/
    end
  end

  test "計画表画面で表示粒度を変更できる" do
    field_id = 'ほ場1'.hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    # 四半期ボタンがアクティブであることを確認
    assert_selector 'a.btn-sm.active', text: /四半期/
    
    # 月ボタンをクリック
    click_link '月'
    
    # 月単位で表示されることを確認
    assert_current_path schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'month'
    )
  end

  test "計画表画面で栽培情報が表示される" do
    field_id = 'ほ場1'.hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    # 栽培情報が表示されることを確認
    assert_selector '.cultivation-item', text: /トマト/
  end

  test "計画表画面でほ場を変更できる" do
    field_id = 'ほ場1'.hash.abs
    visit schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    # ほ場を変更ボタンをクリック
    click_link 'ほ場を変更'
    
    # ほ場選択画面に戻ることを確認
    assert_current_path fields_selection_planning_schedules_path
  end
end

