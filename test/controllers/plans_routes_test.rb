# frozen_string_literal: true

require "test_helper"

class PlansRoutesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:developer)
    log_in_as(@user)
    @plan = cultivation_plans(:plan_2025)
  end
  
  # パスヘルパーのテスト
  test "plans_path should route to index" do
    assert_routing({ path: '/ja/plans', method: :get }, 
                   { controller: 'plans', action: 'index', locale: 'ja' })
  end
  
  test "new_plan_path should route to new" do
    assert_routing({ path: '/ja/plans/new', method: :get }, 
                   { controller: 'plans', action: 'new', locale: 'ja' })
  end
  
  test "plan_path should route to show" do
    assert_routing({ path: "/ja/plans/#{@plan.id}", method: :get }, 
                   { controller: 'plans', action: 'show', id: @plan.id.to_s, locale: 'ja' })
  end
  
  test "select_crop_plans_path should route to select_crop" do
    assert_routing({ path: '/ja/plans/select_crop', method: :get }, 
                   { controller: 'plans', action: 'select_crop', locale: 'ja' })
  end
  
  test "optimizing_plan_path should route to optimizing" do
    assert_routing({ path: "/ja/plans/#{@plan.id}/optimizing", method: :get }, 
                   { controller: 'plans', action: 'optimizing', id: @plan.id.to_s, locale: 'ja' })
  end
  
  test "copy_plan_path should route to copy" do
    assert_routing({ path: "/ja/plans/#{@plan.id}/copy", method: :post }, 
                   { controller: 'plans', action: 'copy', id: @plan.id.to_s, locale: 'ja' })
  end
  
  # パスヘルパーが生成されることを確認
  test "should generate new_plan_path" do
    assert_respond_to self, :new_plan_path
    assert_equal '/ja/plans/new', new_plan_path(locale: :ja)
  end
  
  test "should generate plans_path" do
    assert_respond_to self, :plans_path
    assert_equal '/ja/plans', plans_path(locale: :ja)
  end
  
  test "should generate plan_path" do
    assert_respond_to self, :plan_path
    assert_equal "/ja/plans/#{@plan.id}", plan_path(@plan, locale: :ja)
  end
  
  test "should generate select_crop_plans_path" do
    assert_respond_to self, :select_crop_plans_path
    assert_equal '/ja/plans/select_crop', select_crop_plans_path(locale: :ja)
  end
  
  test "should generate optimizing_plan_path" do
    assert_respond_to self, :optimizing_plan_path
    assert_equal "/ja/plans/#{@plan.id}/optimizing", optimizing_plan_path(@plan, locale: :ja)
  end
  
  test "should generate copy_plan_path" do
    assert_respond_to self, :copy_plan_path
    assert_equal "/ja/plans/#{@plan.id}/copy", copy_plan_path(@plan, locale: :ja)
  end
  
  # ビューで使用されているパスヘルパーのテスト
  test "index view should use new_plan_path" do
    get plans_url
    assert_response :success
    assert_select "a[href=?]", new_plan_path
  end
  
  test "select_crop view should use new_plan_path as back button" do
    get select_crop_plans_url, params: {
      plan_year: 2025,
      farm_id: farms(:farm_tokyo).id,
      plan_name: "Test Plan"
    }
    assert_response :success
    # ビューにnew_plan_pathが含まれることを確認（Fixed Bottom Barに）
    assert_match /new_plan_path/, response.body
  end
end

