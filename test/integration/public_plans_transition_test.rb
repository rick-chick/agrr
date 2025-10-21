# frozen_string_literal: true

require "test_helper"

class PublicPlansTransitionTest < ActionDispatch::IntegrationTest
  setup do
    # Anonymous user (no authentication required)
    @user = User.create!(
      email: 'anonymous@agrr.app',
      name: 'Anonymous User',
      google_id: 'anon123',
      is_anonymous: true
    )
    
    # JP reference farm
    @jp_farm = Farm.create!(
      user: @user,
      name: "東京",
      latitude: 35.6895,
      longitude: 139.6917,
      is_reference: true,
      region: 'jp'
    )
    
    # US reference farm
    @us_farm = Farm.create!(
      user: @user,
      name: "California",
      latitude: 36.7783,
      longitude: -119.4179,
      is_reference: true,
      region: 'us'
    )
    
    # JP reference crops
    @jp_crop1 = Crop.create!(
      name: "トマト",
      variety: "桃太郎",
      is_reference: true,
      region: 'jp',
      area_per_unit: 1.0,
      revenue_per_area: 1200.0
    )
    
    @jp_crop2 = Crop.create!(
      name: "キュウリ",
      variety: "夏すずみ",
      is_reference: true,
      region: 'jp',
      area_per_unit: 0.8,
      revenue_per_area: 900.0
    )
    
    # US reference crops
    @us_crop = Crop.create!(
      name: "Tomato",
      variety: "Roma",
      is_reference: true,
      region: 'us',
      area_per_unit: 1.0,
      revenue_per_area: 1000.0
    )
    
    # Farm size
    @farm_size_id = 'home_garden'
  end
  
  # ========================================
  # 正常フロー: 完全な遷移テスト (JP region)
  # ========================================
  
  test "complete transition flow: new -> select_farm_size -> select_crop -> create -> optimizing -> results (JP)" do
    # Step 1: new (栽培地域選択)
    get public_plans_path(locale: 'ja')
    assert_response :success
    assert_select "h2", I18n.t('public_plans.new.title')
    assert_select ".enhanced-selection-card", minimum: 1
    
    # JP farmのみ表示されることを確認
    assert_select ".enhanced-card-title", text: @jp_farm.name
    assert_select ".enhanced-card-title", text: @us_farm.name, count: 0
    
    # Step 2: select_farm_size (農場サイズ選択)
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    assert_response :success
    assert_select "h2", I18n.t('public_plans.select_farm_size.title')
    assert_select ".enhanced-selection-card", count: 3
    
    # セッションに保存されていることを確認
    assert_equal @jp_farm.id, session[:public_plan][:farm_id]
    
    # Step 3: select_crop (作物選択)
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: @farm_size_id }
    assert_response :success
    assert_select "h2", I18n.t('public_plans.select_crop.title')
    
    # JP作物のみ表示されることを確認
    assert_select ".crop-card", minimum: 2
    
    # セッションに保存されていることを確認
    assert_equal @jp_farm.id, session[:public_plan][:farm_id]
    assert_equal @farm_size_id, session[:public_plan][:farm_size_id]
    assert_equal 30, session[:public_plan][:total_area]
    
    # Step 4: create (計画作成)
    assert_difference('CultivationPlan.count', 1) do
      post public_plans_path(locale: 'ja'), params: { crop_ids: [@jp_crop1.id, @jp_crop2.id] }
    end
    
    plan = CultivationPlan.last
    assert_equal 'public', plan.plan_type
    # Public planはAnonymous Userが設定される（user_idはnilまたはAnonymous User）
    assert_not_nil plan.user_id # Anonymous Userのid
    assert_not_nil plan.session_id
    assert_redirected_to optimizing_public_plans_path(locale: 'ja')
    
    # セッションに計画IDが保存されていることを確認
    assert_equal plan.id, session[:public_plan][:plan_id]
    
    # Step 5: optimizing (最適化進捗画面)
    follow_redirect!
    assert_response :success
    assert_select ".compact-header-card"
    assert_select ".fixed-progress-bar"
    
    # 計画を完了状態に変更
    plan.update!(status: :completed)
    
    # completedの場合はresultsにリダイレクト
    get optimizing_public_plans_path(locale: 'ja')
    assert_redirected_to results_public_plans_path(locale: 'ja')
    
    # Step 6: results (結果表示)
    follow_redirect!
    assert_response :success
    assert_select ".gantt-section"
    assert_select ".gantt-header"
    assert_select "#gantt-chart-container"
  end
  
  # ========================================
  # 正常フロー: US region
  # ========================================
  
  test "complete transition flow with US region" do
    # Step 1: new (US locale)
    get public_plans_path(locale: 'us')
    assert_response :success
    
    # US farmのみ表示されることを確認
    assert_select ".enhanced-card-title", text: @us_farm.name
    assert_select ".enhanced-card-title", text: @jp_farm.name, count: 0
    
    # Step 2: select_farm_size
    get select_farm_size_public_plans_path(locale: 'us', farm_id: @us_farm.id)
    assert_response :success
    assert_equal @us_farm.id, session[:public_plan][:farm_id]
    
    # Step 3: select_crop
    get select_crop_public_plans_path(locale: 'us'), params: { farm_size_id: @farm_size_id }
    assert_response :success
    
    # US作物のみ表示されることを確認（cropの名前で確認）
    assert_select ".crop-name", text: @us_crop.name
    
    # Step 4: create
    assert_difference('CultivationPlan.count', 1) do
      post public_plans_path(locale: 'us'), params: { crop_ids: [@us_crop.id] }
    end
    
    plan = CultivationPlan.last
    assert_equal 'public', plan.plan_type
    assert_redirected_to optimizing_public_plans_path(locale: 'us')
  end
  
  # ========================================
  # エラーケース: セッションなし・不正なデータ
  # ========================================
  
  test "select_farm_size requires valid farm_id" do
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: 999999)
    assert_redirected_to public_plans_path(locale: 'ja')
    assert_equal I18n.t('public_plans.errors.select_region'), flash[:alert]
  end
  
  test "select_crop requires session data" do
    # セッションなしでアクセス
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: @farm_size_id }
    assert_redirected_to public_plans_path(locale: 'ja')
    assert_equal I18n.t('public_plans.errors.restart'), flash[:alert]
  end
  
  test "select_crop requires valid farm_size_id" do
    # セッションを設定
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    
    # 無効なfarm_size_idでアクセス
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: 'invalid_size' }
    assert_redirected_to select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    assert_equal I18n.t('public_plans.errors.select_farm_size'), flash[:alert]
  end
  
  test "create requires session data" do
    # 新しいセッションで作成を試行
    open_session do |sess|
      sess.post public_plans_path(locale: 'ja'), params: { crop_ids: [@jp_crop1.id] }
      sess.assert_redirected_to public_plans_path(locale: 'ja')
      sess.assert_equal I18n.t('public_plans.errors.restart'), sess.flash[:alert]
    end
  end
  
  test "create requires at least one crop" do
    # セッションを設定してから作成
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: @farm_size_id }
    
    # 作物なしで作成
    post public_plans_path(locale: 'ja'), params: { crop_ids: [] }
    assert_redirected_to select_crop_public_plans_path(locale: 'ja')
    assert_equal I18n.t('public_plans.errors.select_crop'), flash[:alert]
  end
  
  test "optimizing redirects to results when plan is completed" do
    plan = create_completed_public_plan
    
    # テスト環境ではplan_idパラメータで直接アクセス可能
    get optimizing_public_plans_path(locale: 'ja'), params: { plan_id: plan.id }
    assert_redirected_to results_public_plans_path(locale: 'ja')
  end
  
  test "results redirects to optimizing when plan is not completed" do
    plan = create_pending_public_plan
    
    # テスト環境ではplan_idパラメータで直接アクセス可能
    get results_public_plans_path(locale: 'ja'), params: { plan_id: plan.id }
    assert_redirected_to optimizing_public_plans_path(locale: 'ja')
  end
  
  # ========================================
  # セッション管理: 各ステップでのセッション状態確認
  # ========================================
  
  test "session is maintained throughout the flow" do
    # Step 1: select_farm_size でセッション開始
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    assert_equal @jp_farm.id, session[:public_plan][:farm_id]
    
    # Step 2: select_crop でセッション更新
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: @farm_size_id }
    assert_equal @jp_farm.id, session[:public_plan][:farm_id]
    assert_equal @farm_size_id, session[:public_plan][:farm_size_id]
    assert_equal 30, session[:public_plan][:total_area]
    
    # Step 3: create でセッション更新（plan_id保存）
    post public_plans_path(locale: 'ja'), params: { crop_ids: [@jp_crop1.id] }
    plan = CultivationPlan.last
    assert_equal plan.id, session[:public_plan][:plan_id]
  end
  
  # ========================================
  # 地域別フィルタリング
  # ========================================
  
  test "JP locale shows only JP farms and crops" do
    get public_plans_path(locale: 'ja')
    assert_response :success
    assert_select ".enhanced-card-title", text: @jp_farm.name
    assert_select ".enhanced-card-title", text: @us_farm.name, count: 0
    
    get select_farm_size_public_plans_path(locale: 'ja', farm_id: @jp_farm.id)
    get select_crop_public_plans_path(locale: 'ja'), params: { farm_size_id: @farm_size_id }
    
    # JP作物が表示される
    assert_select ".crop-name", text: @jp_crop1.name
  end
  
  test "US locale shows only US farms and crops" do
    get public_plans_path(locale: 'us')
    assert_response :success
    assert_select ".enhanced-card-title", text: @us_farm.name
    assert_select ".enhanced-card-title", text: @jp_farm.name, count: 0
    
    get select_farm_size_public_plans_path(locale: 'us', farm_id: @us_farm.id)
    get select_crop_public_plans_path(locale: 'us'), params: { farm_size_id: @farm_size_id }
    
    # US作物が表示される
    assert_select ".crop-name", text: @us_crop.name
  end
  
  # ========================================
  # テスト用plan_idパラメータ (開発・テスト環境)
  # ========================================
  
  test "can access optimizing and results with plan_id parameter in test environment" do
    plan = create_completed_public_plan
    
    # plan_idパラメータで直接アクセス可能（テスト環境のみ）
    get optimizing_public_plans_path(locale: 'ja'), params: { plan_id: plan.id }
    assert_redirected_to results_public_plans_path(locale: 'ja')
    
    get results_public_plans_path(locale: 'ja'), params: { plan_id: plan.id }
    assert_response :success
  end
  
  # ========================================
  # ヘルパーメソッド
  # ========================================
  
  private
  
  def create_completed_public_plan
    plan = CultivationPlan.create!(
      farm: @jp_farm,
      user: nil,
      session_id: 'test_session_123',
      plan_type: 'public',
      total_area: 30.0,
      status: :completed,
      planning_start_date: Date.current.beginning_of_year,
      planning_end_date: Date.current.end_of_year
    )
    
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "Test Field",
      area: 30.0,
      daily_fixed_cost: 1000.0
    )
    
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @jp_crop1.name,
      variety: @jp_crop1.variety,
      agrr_crop_id: @jp_crop1.name
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 30.0,
      start_date: Date.current + 10.days,
      completion_date: Date.current + 100.days,
      cultivation_days: 90,
      estimated_cost: 50000.0,
      status: :completed,
      optimization_result: {
        start_date: (Date.current + 10.days).to_s,
        completion_date: (Date.current + 100.days).to_s,
        days: 90,
        cost: 50000.0,
        gdd: 2000.0,
        raw: { stages: [] }
      }
    )
    
    plan
  end
  
  def create_pending_public_plan
    plan = CultivationPlan.create!(
      farm: @jp_farm,
      user: nil,
      session_id: 'test_session_456',
      plan_type: 'public',
      total_area: 30.0,
      status: :pending,
      planning_start_date: Date.current.beginning_of_year,
      planning_end_date: Date.current.end_of_year
    )
    
    field = CultivationPlanField.create!(
      cultivation_plan: plan,
      name: "Test Field",
      area: 30.0,
      daily_fixed_cost: 1000.0
    )
    
    crop = CultivationPlanCrop.create!(
      cultivation_plan: plan,
      name: @jp_crop1.name,
      agrr_crop_id: @jp_crop1.name
    )
    
    FieldCultivation.create!(
      cultivation_plan: plan,
      cultivation_plan_field: field,
      cultivation_plan_crop: crop,
      area: 30.0,
      status: :pending
    )
    
    plan
  end
end

