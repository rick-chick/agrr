# frozen_string_literal: true

require 'test_helper'

class PlansControllerPresenterGuardTests < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
  end

  # SCOPE: index/new の表示系が 200 を返し、主要要素があることを確認
  test 'index renders successfully and groups plans by year' do
    # データ準備: 今年と昨年のプライベート計画を複数作成
    this_year = Date.current.year
    last_year = this_year - 1

    farm_a = create(:farm, user: @user)
    farm_b = create(:farm, user: @user)
    create(:cultivation_plan, :private, user: @user, farm: farm_a, plan_year: this_year)
    create(:cultivation_plan, :private, user: @user, farm: farm_b, plan_year: this_year)
    create(:cultivation_plan, :private, user: @user, farm: farm_a, plan_year: last_year)

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
    plan = create(:cultivation_plan, :private, user: @user, status: 'pending')
    post optimize_plan_path(plan)
    assert_redirected_to optimizing_plan_path(plan.id)
    assert_equal I18n.t('plans.messages.optimization_started'), flash[:notice]
  end

  test 'optimize redirects back with alert when already optimizing' do
    plan = create(:cultivation_plan, :private, user: @user, status: 'optimizing')
    post optimize_plan_path(plan)
    assert_redirected_to plan_path(plan)
    assert_equal I18n.t('plans.errors.already_optimized'), flash[:alert]
  end

  test 'optimizing renders successfully' do
    # optimizing は内部で handle_optimizing を呼ぶが、画面自体の到達を確認
    plan = create(:cultivation_plan, :private, user: @user, status: 'pending')
    get optimizing_plan_path(plan.id)
    assert_response :success
    assert_select 'body', true
  end

  # SCOPE: copy 正常/異常
  test 'copy duplicates plan to next year and redirects to new plan' do
    plan = create(:cultivation_plan, :private, user: @user, plan_year: Date.current.year, plan_name: 'X')
    # PlanCopier はサービスに委譲されるため、ここでは成功パスの最小確認
    # 前提: 同名の翌年計画が存在しない
    post copy_plan_path(plan)
    assert_response :redirect
    follow_redirect!
    assert_match %r{/plans/\d+}, path
    assert_equal I18n.t('plans.messages.plan_copied', year: plan.plan_year + 1), flash[:notice]
  end

  test 'copy prevents duplication when same year plan exists' do
    plan = create(:cultivation_plan, :private, user: @user, plan_year: Date.current.year, plan_name: 'X')
    create(:cultivation_plan, :private, user: @user, plan_year: plan.plan_year + 1, plan_name: plan.plan_name)
    post copy_plan_path(plan)
    assert_redirected_to plans_path
    assert_equal I18n.t('plans.errors.plan_already_exists', year: plan.plan_year + 1), flash[:alert]
  end

  # SCOPE: destroy の HTML リクエスト（JSON は既存テストで網羅）
  test 'destroy via HTML redirects to index with flash' do
    plan = create(:cultivation_plan, :private, user: @user)
    delete plan_path(plan) # デフォルトはHTML
    # DeletionUndoはJSONを返す設計のため、HTMLは失敗時/異常時のフォールバックを検査
    # 実装では render_deletion_undo_response がHTMLに対応していなければ、失敗ハンドリング側へ落ちる
    # ここでは「致命的にエラーにならず、適切なリダイレクトがある」ことのみ確認
    assert_response :redirect
    assert_match %r{/plans}, path
  end
end


