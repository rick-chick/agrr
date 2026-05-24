# frozen_string_literal: true

require "test_helper"

# HTML 応答形（redirect / 一覧描画）の境界のみ。JSON 契約は api/v1/masters/farms と deletion_undos が担保する。
class FarmsControllerTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    farm = create(:farm, user: @user, name: "テスト農場")
    display_name = farm.display_name

    assert_difference -> { Farm.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete farm_path(farm) # HTMLリクエスト
        assert_redirected_to farms_path
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: display_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  # HTML index の行絞り込み（自分の農場のみ／管理者の参照農場）は
  # FarmListRowsBundleInteractor のユニットテスト、テンプレート描画は
  # test/views/farms_index_view_test.rb が担保する。ここは配線が通ることのみ確認する。
  test "GET index HTML renders successfully" do
    sign_in_as @user
    create(:farm, user: @user, name: "My Listed Farm")

    get farms_path
    assert_response :success
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は FarmPolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/farm_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
