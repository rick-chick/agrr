# frozen_string_literal: true

require "test_helper"

class PlansTransitionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:developer)
    sign_in_as(@user)
    
    @farm = farms(:farm_tokyo)
    @crop1 = crops(:tomato_user)
    @crop2 = crops(:cucumber_user)
    
    # テスト用の年度
    @plan_year = 2025
  end
  
  # ========================================
  # 正常フロー: 完全な遷移テスト
  # ========================================
  
  test "complete transition flow: index -> new -> select_crop -> create -> optimizing -> show" do
    # Step 1: index
    get plans_path
    assert_response :success
    assert_select "h1", I18n.t('plans.index.title')
    
    # Step 2: new
    get new_plan_path
    assert_response :success
    assert_select "h2", I18n.t('plans.new.title')
    assert_select "select[name='plan_year']"
    assert_select "input[type='radio'][name='farm_id']", minimum: 1
    
    # Step 3: select_crop
    get select_crop_plans_path, params: {
      plan_year: @plan_year,
      farm_id: @farm.id,
      plan_name: "統合テスト計画"
    }
    assert_response :success
    assert_select "h2", I18n.t('plans.select_crop.title')
    
    # セッションに保存されていることを確認
    assert_equal @plan_year, session[:plan_data][:plan_year]
    assert_equal @farm.id, session[:plan_data][:farm_id]
    assert_equal "統合テスト計画", session[:plan_data][:plan_name]
    
    # Step 4: create
    assert_difference('CultivationPlan.count', 1) do
      post plans_path, params: { crop_ids: [@crop1.id, @crop2.id] }
    end
    
    plan = CultivationPlan.last
    assert_equal 'private', plan.plan_type
    assert_equal @plan_year, plan.plan_year
    assert_equal @user.id, plan.user_id
    assert_redirected_to optimizing_plan_path(plan)
    
    # セッションに計画IDが保存されていることを確認
    assert_equal plan.id, session[:plan_data][:plan_id]
    
    # Step 5: optimizing
    follow_redirect!
    assert_response :success
    assert_select ".optimizing-card"
    
    # 計画を完了状態に変更
    plan.update!(status: :completed)
    
    # completedの場合はshowにリダイレクト
    get optimizing_plan_path(plan)
    assert_redirected_to plan_path(plan)
    
    # Step 6: show
    follow_redirect!
    assert_response :success
    # Private planはapplication layoutを使用
    assert_select "h1, .gantt-header, .plan-detail"
  end
  
  # ========================================
  # エラーケース: セッションなし・不正なデータ
  # ========================================
  
  test "select_crop requires plan_year and farm_id" do
    # パラメータなしでアクセス
    get select_crop_plans_path
    assert_redirected_to new_plan_path
    assert_equal I18n.t('plans.errors.select_year_and_farm'), flash[:alert]
  end
  
  test "select_crop requires valid farm_id" do
    # 存在しないfarm_idでアクセス
    get select_crop_plans_path, params: {
      plan_year: @plan_year,
      farm_id: 999999
    }
    assert_redirected_to new_plan_path
    assert_equal I18n.t('plans.errors.farm_not_found'), flash[:alert]
  end
  
  test "create requires session data" do
    # セッションなしで作成を試行（新しいセッションを開始）
    open_session do |sess|
      # 新しいセッションでもまずログインする必要がある
      session_id = create_session_for(@user)
      sess.cookies[:session_id] = session_id
      
      # セッションデータなしでPOST
      sess.post plans_path, params: { crop_ids: [@crop1.id] }
      sess.assert_redirected_to new_plan_path
      sess.assert_equal I18n.t('plans.errors.restart'), sess.flash[:alert]
    end
  end
  
  test "create requires at least one crop" do
    # セッションを設定してから作成
    get select_crop_plans_path, params: {
      plan_year: @plan_year,
      farm_id: @farm.id,
      plan_name: "Test"
    }
    
    # 作物なしで作成
    post plans_path, params: { crop_ids: [] }
    assert_redirected_to select_crop_plans_path
    assert_equal I18n.t('plans.errors.select_crop'), flash[:alert]
  end
  
  test "optimizing redirects to show when plan is completed" do
    plan = create_completed_plan
    
    get optimizing_plan_path(plan)
    assert_redirected_to plan_path(plan)
  end
  
  test "show redirects to optimizing when plan is not completed" do
    plan = create_pending_plan
    
    get plan_path(plan)
    assert_redirected_to optimizing_plan_path(plan)
  end
  
  # ========================================
  # セキュリティ: 他ユーザーの計画にアクセスできない
  # ========================================
  
  test "cannot access other user's plan in optimizing" do
    other_user = users(:two)
    other_plan = create_plan_for_user(other_user)
    
    # 他ユーザーの計画にアクセスすると一覧画面にリダイレクト
    get optimizing_plan_path(other_plan)
    assert_redirected_to plans_path
    assert_includes flash[:alert], "見つかりません"
  end
  
  test "cannot access other user's plan in show" do
    other_user = users(:two)
    other_plan = create_plan_for_user(other_user)
    
    # 他ユーザーの計画にアクセスすると一覧画面にリダイレクト
    get plan_path(other_plan)
    assert_redirected_to plans_path
    assert_includes flash[:alert], "見つかりません"
  end
  
  # ========================================
  # 計画コピー機能
  # ========================================
  
  test "copy creates new plan for next year" do
    source_plan = create_completed_plan
    
    assert_difference('CultivationPlan.count', 1) do
      post copy_plan_path(source_plan)
    end
    
    new_plan = CultivationPlan.last
    assert_equal source_plan.plan_year + 1, new_plan.plan_year
    assert_redirected_to plan_path(new_plan)
    assert_equal I18n.t('plans.messages.plan_copied', year: new_plan.plan_year), flash[:notice]
  end
  
  test "copy fails if plan for next year already exists" do
    source_plan = create_completed_plan
    
    # 同じ年度の計画を作成
    CultivationPlan.create!(
      farm: source_plan.farm,
      user: @user,
      plan_year: source_plan.plan_year + 1,
      plan_name: source_plan.plan_name,
      plan_type: 'private',
      total_area: 100.0,
      status: :completed,
      planning_start_date: Date.new(source_plan.plan_year, 1, 1),
      planning_end_date: Date.new(source_plan.plan_year + 2, 12, 31)
    )
    
    assert_no_difference('CultivationPlan.count') do
      post copy_plan_path(source_plan)
    end
    
    assert_redirected_to plans_path
    assert_includes flash[:alert], "既に存在"
  end
  
  # ========================================
  # ヘルパーメソッド
  # ========================================
  
  private
  
  def create_completed_plan
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      plan_year: @plan_year,
      plan_name: "Test Plan",
      plan_type: 'private',
      total_area: 100.0,
      status: :completed,
      planning_start_date: Date.new(@plan_year - 1, 1, 1),
      planning_end_date: Date.new(@plan_year + 1, 12, 31)
    )
    
    # Field and crop data
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "Test Field",
      area: 100.0,
      daily_fixed_cost: 1000.0
    )
    
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: "Test Crop",
      agrr_crop_id: "test_crop"
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 100.0,
      start_date: Date.new(@plan_year, 4, 1),
      completion_date: Date.new(@plan_year, 8, 31),
      cultivation_days: 150,
      estimated_cost: 50000.0,
      status: :completed
    )
    
    plan
  end
  
  def create_pending_plan
    plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      plan_year: @plan_year,
      plan_name: "Pending Plan",
      plan_type: 'private',
      total_area: 100.0,
      status: :pending,
      planning_start_date: Date.new(@plan_year - 1, 1, 1),
      planning_end_date: Date.new(@plan_year + 1, 12, 31)
    )
    
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "Test Field",
      area: 100.0,
      daily_fixed_cost: 1000.0
    )
    
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: "Test Crop",
      agrr_crop_id: "test_crop"
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 100.0,
      status: :pending
    )
    
    plan
  end
  
  def create_plan_for_user(user)
    other_farm = Farm.create!(
      user: user,
      name: "Other Farm",
      latitude: 35.0,
      longitude: 139.0
    )
    
    CultivationPlan.create!(
      farm: other_farm,
      user: user,
      plan_year: @plan_year,
      plan_name: "Other User Plan",
      plan_type: 'private',
      total_area: 100.0,
      status: :completed,
      planning_start_date: Date.new(@plan_year - 1, 1, 1),
      planning_end_date: Date.new(@plan_year + 1, 12, 31)
    )
  end
end

