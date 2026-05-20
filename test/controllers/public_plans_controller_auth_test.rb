# frozen_string_literal: true

require "test_helper"

# PublicPlansControllerの認証関連テスト（ActionDispatch::IntegrationTest）
# 重いセットアップ（農場・気象データ15年分・作物・生育ステージ）を不要にするために分離
class PublicPlansControllerAuthTest < ActionDispatch::IntegrationTest
  test "POST /api/v1/public_plans/save_plan - 未認証の場合401を返す" do
    # 認証なしでAPIリクエスト
    post "/api/v1/public_plans/save_plan",
         params: { plan_id: 1 },
         as: :json

    # レスポンス確認
    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_not response_body["success"]
    assert_equal I18n.t("auth.api.login_required"), response_body["error"]
  end
end
