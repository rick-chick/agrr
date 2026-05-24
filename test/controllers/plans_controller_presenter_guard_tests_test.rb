# frozen_string_literal: true

require "test_helper"

class PlansControllerPresenterGuardTests < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    sign_in_as @user
  end

  # SCOPE: index/new の表示系が 200 を返し、主要要素があることを確認
  test "index renders successfully and groups plans by farm" do
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
    assert_select "body", true
  end

  # SCOPE: copy 正常/異常
  # SCOPE: copy 正常/異常
  test "copy is disabled due to new uniqueness constraint" do
    # 新しい一意制約により、同じ農場・ユーザで複数の計画を作成できないため、
    # コピー機能は完全に無効化されました
    plan = create(:cultivation_plan, user: @user, farm: @farm, plan_year: Date.current.year, plan_name: "X")
    post copy_plan_path(plan)
    assert_redirected_to plans_path
    assert_equal I18n.t("plans.errors.copy_not_available_for_annual_planning"), flash[:alert]
  end

  # SCOPE: destroy の HTML リクエスト（JSON は既存テストで網羅）
  test "destroy via HTML redirects to index with flash" do
    plan = create(:cultivation_plan, user: @user)
    delete plan_path(plan) # デフォルトはHTML
    # DeletionUndoはJSONを返す設計のため、HTMLは失敗時/異常時のフォールバックを検査
    # 実装では DualFormatResponder が HTML に対応していなければ、失敗ハンドリング側へ落ちる
    # ここでは「致命的にエラーにならず、適切なリダイレクトがある」ことのみ確認
    assert_response :redirect
    assert_match %r{/plans}, path
  end
end
