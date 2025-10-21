# frozen_string_literal: true

require "test_helper"

class PlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:developer)
    sign_in_as(@user)
    
    @farm = farms(:farm_tokyo)
    @crop = crops(:tomato_user)
    
    @plan = cultivation_plans(:plan_2025)
  end
  
  test "should get index" do
    get plans_url
    assert_response :success
  end
  
  test "should get new" do
    get new_plan_url
    assert_response :success
  end
  
  test "should get select_crop" do
    get select_crop_plans_url, params: {
      plan_year: 2025,
      farm_id: @farm.id,
      plan_name: "Test Plan"
    }
    assert_response :success
  end
  
  test "should create plan" do
    session[:plan_data] = {
      plan_year: 2025,
      farm_id: @farm.id,
      plan_name: "Test Plan",
      total_area: 100.0
    }
    
    assert_difference('CultivationPlan.count') do
      post plans_url, params: { crop_ids: [@crop.id] }
    end
    
    plan = CultivationPlan.last
    assert_equal 'private', plan.plan_type
    assert_equal 2025, plan.plan_year
    assert_redirected_to optimizing_plan_path(plan)
  end
  
  test "should show plan" do
    get plan_url(@plan)
    assert_response :success
  end
  
  test "should get optimizing" do
    get optimizing_plan_url(@plan)
    assert_response :success
  end
  
  test "should copy plan" do
    assert_difference('CultivationPlan.count') do
      post copy_plan_url(@plan)
    end
    
    new_plan = CultivationPlan.last
    assert_equal @plan.plan_year + 1, new_plan.plan_year
    assert_redirected_to plan_path(new_plan)
  end
  
  test "should not access other user's plan" do
    other_user = users(:two)
    sign_in_as(other_user)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get plan_url(@plan)
    end
  end
  
  # User associations tests
  test "should access user's crops in select_crop" do
    get select_crop_plans_url, params: {
      plan_year: 2025,
      farm_id: @farm.id,
      plan_name: "Test Plan"
    }
    assert_response :success
    assert_not_nil assigns(:crops)
  end
  
  test "should only show user's crops" do
    # ユーザーの作物を作成
    user_crop = Crop.create!(
      name: "User Tomato",
      user: @user,
      is_reference: false
    )
    
    get select_crop_plans_url, params: {
      plan_year: 2025,
      farm_id: @farm.id,
      plan_name: "Test Plan"
    }
    
    assert_response :success
    crops = assigns(:crops)
    assert_includes crops, user_crop
    # 参照作物は含まれない
    assert crops.all? { |c| c.user_id == @user.id && !c.is_reference }
  end
  
  test "should use user's crops in create" do
    user_crop = Crop.create!(
      name: "User Crop",
      user: @user,
      is_reference: false
    )
    
    session[:plan_data] = {
      plan_year: 2025,
      farm_id: @farm.id,
      plan_name: "Test Plan",
      total_area: 100.0
    }
    
    assert_difference('CultivationPlan.count') do
      post plans_url, params: { crop_ids: [user_crop.id] }
    end
    
    plan = CultivationPlan.last
    assert_equal @user.id, plan.user_id
  end
end

