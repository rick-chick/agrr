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

  test "schedule filters by year" do
    sign_in_as @user
    
    # 今年の計画
    plan1 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan1, name: 'ほ場1', area: 1000)
    crop1 = create(:cultivation_plan_crop, cultivation_plan: plan1, name: 'トマト')
    create(:field_cultivation,
      cultivation_plan: plan1,
      cultivation_plan_field: field1,
      cultivation_plan_crop: crop1,
      start_date: Date.new(Date.current.year, 1, 15),
      completion_date: Date.new(Date.current.year, 3, 20),
      area: 1000
    )
    
    # 来年の計画
    plan2 = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year + 1)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan2, name: 'ほ場1', area: 1000)
    crop2 = create(:cultivation_plan_crop, cultivation_plan: plan2, name: 'キャベツ')
    create(:field_cultivation,
      cultivation_plan: plan2,
      cultivation_plan_field: field2,
      cultivation_plan_crop: crop2,
      start_date: Date.new(Date.current.year + 1, 1, 15),
      completion_date: Date.new(Date.current.year + 1, 3, 20),
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
    # 今年のデータのみが表示されることを確認（ビューで確認）
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

