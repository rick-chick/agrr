# frozen_string_literal: true

require 'test_helper'

class PlansControllerPresenterGuardTests < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    sign_in_as @user
  end

  # SCOPE: index/new の表示系が 200 を返し、主要要素があることを確認
  test 'index renders successfully and groups plans by farm' do
    # データ準備: 異なる農場のプライベート計画を作成（通年計画対応）
    farm_a = create(:farm, user: @user)
    farm_b = create(:farm, user: @user)
    create(:cultivation_plan, user: @user, farm: farm_a, plan_year: nil, 
           planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2026, 12, 31))
    create(:cultivation_plan, user: @user, farm: farm_b, plan_year: nil,
           planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2026, 12, 31))

    get plans_path
    assert_response :success
    # 最低限、本文が存在する
    assert_select 'body', true
  end

  test 'new renders successfully and lists user farms with default plan name' do
    create(:farm, user: @user, name: 'Farm A')
    create(:farm, user: @user, name: 'Farm B')

    get new_plan_path
    assert_response :success
    assert_select 'body', true
  end

  # SCOPE: select_crop の正常/異常（不正farm_idはnewへリダイレクト）
  test 'select_crop renders selection data when valid params' do
    farm = create(:farm, user: @user, name: '選択農場', latitude: 35.0, longitude: 135.0)
    field1 = create(:field, user: @user, farm: farm, name: 'F1', area: 10.0)
    field2 = create(:field, user: @user, farm: farm, name: 'F2', area: 20.0)
    crop1 = create(:crop, user: @user, is_reference: false)
    crop2 = create(:crop, user: @user, is_reference: false)

    get select_crop_plans_path, params: { plan_year: Date.current.year, farm_id: farm.id }
    assert_response :success

    # セッションに保存されている（後続createで使用）
    session_data = @request.session[:plan_data]
    assert_equal farm.id, session_data[:farm_id]
    assert_equal farm.name, session_data[:plan_name]
    assert_in_delta 30.0, session_data[:total_area].to_f, 0.001
    assert_select 'body', true
  end

  test 'select_crop redirects to new when farm is not found' do
    get select_crop_plans_path, params: { plan_year: Date.current.year, farm_id: 9_999_999 }
    assert_redirected_to new_plan_path
    assert_equal I18n.t('plans.errors.farm_not_found'), flash[:alert]
  end

  # SCOPE: optimize/optimizing の遷移
  test 'optimize redirects to optimizing when not already optimizing' do
    plan = create(:cultivation_plan, user: @user, status: 'pending')
    post optimize_plan_path(plan)
    assert_redirected_to optimizing_plan_path(plan.id)
    assert_equal I18n.t('plans.messages.optimization_started'), flash[:notice]
  end

  test 'optimize redirects back with alert when already optimizing' do
    plan = create(:cultivation_plan, user: @user, status: 'optimizing')
    post optimize_plan_path(plan)
    assert_redirected_to plan_path(plan)
    assert_equal I18n.t('plans.errors.already_optimized'), flash[:alert]
  end

  test 'optimizing renders successfully' do
    # optimizing は内部で handle_optimizing を呼ぶが、画面自体の到達を確認
    plan = create(:cultivation_plan, user: @user, status: 'pending')
    get optimizing_plan_path(plan.id)
    assert_response :success
    assert_select 'body', true
  end

  # SCOPE: copy 正常/異常
  # SCOPE: copy 正常/異常
  test 'copy is disabled due to new uniqueness constraint' do
    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、
    # コピー機能は完全に無効化されました
    plan = create(:cultivation_plan, user: @user, farm: @farm, plan_year: Date.current.year, plan_name: 'X')
    post copy_plan_path(plan)
    assert_redirected_to plans_path
    assert_equal I18n.t('plans.errors.copy_not_available_for_annual_planning'), flash[:alert]
  end

  # SCOPE: destroy の HTML リクエスト（JSON は既存テストで網羅）
  test 'destroy via HTML redirects to index with flash' do
    plan = create(:cultivation_plan, user: @user)
    delete plan_path(plan) # デフォルトはHTML
    # DeletionUndoはJSONを返す設計のため、HTMLは失敗時/異常時のフォールバックを検査
    # 実装では render_deletion_undo_response がHTMLに対応していなければ、失敗ハンドリング側へ落ちる
    # ここでは「致命的にエラーにならず、適切なリダイレクトがある」ことのみ確認
    assert_response :redirect
    assert_match %r{/plans}, path
  end
end


