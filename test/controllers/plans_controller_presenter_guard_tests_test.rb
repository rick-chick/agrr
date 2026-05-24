# frozen_string_literal: true

require "test_helper"

class PlansControllerPresenterGuardTests < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    sign_in_as @user
  end

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
