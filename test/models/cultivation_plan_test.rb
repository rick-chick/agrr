# frozen_string_literal: true

require "test_helper"

class CultivationPlanTest < ActiveSupport::TestCase
  setup do
    @user = users(:developer)
    @farm = farms(:farm_tokyo)
  end
  
  test "should create public plan" do
    plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 100.0,
      plan_type: 'public',
      session_id: 'test_session'
    )
    
    assert plan.plan_type_public?
    assert_equal 'test_session', plan.session_id
    assert_nil plan.user_id
  end
  
  test "should create private plan" do
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      plan_type: 'private',
      plan_year: 2025,
      plan_name: "Test Plan",
      planning_start_date: Date.new(2024, 1, 1),
      planning_end_date: Date.new(2026, 12, 31)
    )
    
    assert plan.plan_type_private?
    assert_equal 2025, plan.plan_year
    assert_equal @user.id, plan.user_id
  end
  
  test "should validate private plan attributes" do
    plan = CultivationPlan.new(
      farm: @farm,
      total_area: 100.0,
      plan_type: 'private'
    )
    
    assert_not plan.valid?
    assert_includes plan.errors[:user_id], "を入力してください"
    assert_includes plan.errors[:plan_year], "を入力してください"
  end
  
  test "should calculate planning dates from year" do
    dates = CultivationPlan.calculate_planning_dates(2025)
    
    assert_equal Date.new(2024, 1, 1), dates[:start_date]
    assert_equal Date.new(2026, 12, 31), dates[:end_date]
  end
  
  test "should return display name" do
    public_plan = cultivation_plans(:public_plan_1)
    assert_equal I18n.t('models.cultivation_plan.public_plan_name'), public_plan.display_name
    
    private_plan = cultivation_plans(:plan_2025)
    assert_includes private_plan.display_name, "2025"
  end
  
  test "should scope by user and year" do
    plans = CultivationPlan.for_user_and_year(@user, 2025)
    
    assert plans.all?(&:plan_type_private?)
    assert plans.all? { |p| p.user_id == @user.id }
    assert plans.all? { |p| p.plan_year == 2025 }
  end
end

