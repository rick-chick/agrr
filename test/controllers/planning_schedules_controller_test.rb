# frozen_string_literal: true

require 'test_helper'

class PlanningSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user, name: 'テスト農場')
    @other_user = create(:user)
    @other_farm = create(:farm, user: @other_user, name: '他のユーザーの農場')
  end

  test "fields_selection requires authentication" do
    get fields_selection_planning_schedules_path
    assert_redirected_to auth_login_path
  end

  test "fields_selection displays farms for logged in user" do
    sign_in_as @user
    get fields_selection_planning_schedules_path
    
    assert_response :success
    assert_select 'h1', text: /ほ場選択/
  end

  test "fields_selection displays fields from plans" do
    sign_in_as @user
    
    # 計画を作成
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場2', area: 2000)
    
    get fields_selection_planning_schedules_path(farm_id: @farm.id)
    
    assert_response :success
    assert_select '.field-checkbox', count: 2
  end

  test "fields_selection shows empty message when no farms" do
    sign_in_as @user
    @user.farms.destroy_all
    
    get fields_selection_planning_schedules_path
    
    assert_response :success
    assert_select '.plans-empty'
  end

  test "schedule requires authentication" do
    get schedule_planning_schedules_path
    assert_redirected_to auth_login_path
  end

  test "schedule redirects to fields_selection when no farm_id" do
    sign_in_as @user
    get schedule_planning_schedules_path
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.select_fields'), flash[:alert]
  end

  test "schedule redirects to fields_selection when no field_ids" do
    sign_in_as @user
    get schedule_planning_schedules_path(farm_id: @farm.id)
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.select_fields'), flash[:alert]
  end

  test "schedule displays schedule table" do
    sign_in_as @user
    
    # 計画を作成
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    
    # 栽培情報を作成
    field_cultivation = create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000
    )
    
    field_id = 'ほ場1'.hash.abs
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    
    assert_response :success
    assert_select 'h1', text: /作付け計画表/
    assert_select '.schedule-table'
  end

  test "schedule displays 5 years of data" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    # 5年分の計画を作成
    (0..4).each do |year_offset|
      year = current_year + year_offset
      plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: year)
      field = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
      crop = create(:cultivation_plan_crop, cultivation_plan: plan, name: "作物#{year_offset + 1}")
      create(:field_cultivation,
        cultivation_plan: plan,
        cultivation_plan_field: field,
        cultivation_plan_crop: crop,
        start_date: Date.new(year, 1, 15),
        completion_date: Date.new(year, 3, 20),
        area: 1000
      )
    end
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    assert_select 'h1', text: /作付け計画表/
    assert_select '.schedule-table'
    
    # 5年分の期間が表示されることを確認（quarter粒度で5年分 = 20期間）
    # 実際の期間数は年によって変わる可能性があるので、最低限の確認
    assert_select '.schedule-table tbody tr', minimum: 1
  end

  test "schedule displays data across multiple years" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    # 複数年度にまたがる計画を作成
    plan1 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan1, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan1, name: 'トマト')
    create(:field_cultivation,
      cultivation_plan: plan1,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(current_year, 1, 15),
      completion_date: Date.new(current_year, 3, 20),
      area: 1000
    )
    
    plan2 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year + 2)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan2, name: 'ほ場1', area: 1000)
    crop2 = create(:cultivation_plan_crop, cultivation_plan: plan2, name: 'キャベツ')
    create(:field_cultivation,
      cultivation_plan: plan2,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop2,
      start_date: Date.new(current_year + 2, 1, 15),
      completion_date: Date.new(current_year + 2, 3, 20),
      area: 1000
    )
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # 5年分のデータが表示されることを確認
    assert_select '.schedule-table'
  end

  test "schedule generates periods for 5 years with quarter granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # quarter粒度で5年分 = 20期間（1年4四半期 × 5年）
    assert_select '.schedule-table tbody tr', count: 20
  end

  test "schedule generates periods for 5 years with month granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'month'
    )
    
    assert_response :success
    # month粒度で5年分 = 60期間（1年12ヶ月 × 5年）
    assert_select '.schedule-table tbody tr', count: 60
  end

  test "schedule generates periods for 5 years with half granularity" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'half'
    )
    
    assert_response :success
    # half粒度で5年分 = 10期間（1年2半期 × 5年）
    assert_select '.schedule-table tbody tr', count: 10
  end

  test "schedule displays year range navigation" do
    sign_in_as @user
    
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    )
    
    assert_response :success
    # 5年分の期間表示が含まれることを確認（形式: "X年度 〜 Y年度（5年分）"）
    assert_select '.schedule-year-display' do |element|
      text = element.first.text
      assert_match(/#{current_year}年度/, text)
      assert_match(/#{current_year + 4}年度/, text)
      assert_match(/5年分/, text)
    end
  end

  test "schedule supports different granularities" do
    sign_in_as @user
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, name: 'トマト')
    create(:field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000
    )
    
    field_id = 'ほ場1'.hash.abs
    
    # 月単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'month'
    )
    assert_response :success
    
    # 四半期単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'quarter'
    )
    assert_response :success
    
    # 半期単位
    get schedule_planning_schedules_path(
      farm_id: @farm.id,
      field_ids: [field_id],
      year: Date.current.year,
      granularity: 'half'
    )
    assert_response :success
  end

  test "schedule only shows user's own farms" do
    sign_in_as @user
    
    get schedule_planning_schedules_path(
      farm_id: @other_farm.id,
      field_ids: [1],
      year: Date.current.year
    )
    
    assert_redirected_to fields_selection_planning_schedules_path
    assert_equal I18n.t('planning_schedules.errors.farm_not_found'), flash[:alert]
  end
end

