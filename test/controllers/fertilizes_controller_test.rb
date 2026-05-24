# frozen_string_literal: true

require "test_helper"
require "time"

# HTML 応答形（redirect / 一覧描画）の境界のみ。認可・永続化の網羅は
# test/domain/fertilize/interactors/* と test/controllers/api/v1/masters/fertilizes_controller_test.rb。

class FertilizesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)
    @other_user = create(:user)

    # 参照肥料（user_id: nil）
    @reference_fertilize = create(:fertilize, is_reference: true, user_id: nil)
    # 一般ユーザーの肥料
    @user_fertilize = create(:fertilize, :user_owned, user: @user)
    # 他のユーザーの肥料
    @other_user_fertilize = create(:fertilize, :user_owned, user: @other_user)
    # 管理者の肥料
    @admin_fertilize = create(:fertilize, :user_owned, user: @admin_user)
  end

  # ========== index アクションのテスト ==========

  test "一般ユーザーのindexは自身の非参照肥料のみ表示" do
    sign_in_as @user
    get fertilizes_path

    assert_response :success
    body = response.body
    # 自分の非参照肥料のみ表示される
    assert_includes body, @user_fertilize.name
    refute_includes body, @reference_fertilize.name
    refute_includes body, @other_user_fertilize.name
    refute_includes body, @admin_fertilize.name
  end

  test "管理者のindexは自身の肥料と参照肥料を表示し他人の肥料は表示しない" do
    sign_in_as @admin_user
    get fertilizes_path

    assert_response :success
    body = response.body
    assert_includes body, @admin_fertilize.name
    assert_includes body, @reference_fertilize.name
    refute_includes body, @user_fertilize.name
    refute_includes body, @other_user_fertilize.name
  end

  # ========== show アクションのテスト ==========

  test "show の権限拒否は redirect + flash へマッピングされる" do
    sign_in_as @user
    get fertilize_path(@reference_fertilize)

    assert_redirected_to fertilizes_path
    assert_equal I18n.t("fertilizes.flash.no_permission"), flash[:alert]
  end

  # is_reference（admin のみ設定・変更可）の認可は FertilizeCreate/UpdateInteractor が
  # 判定する → test/domain/fertilize/interactors/fertilize_{create,update}_interactor_test.rb。
  # 以下の controller テストは認可失敗の HTTP 応答（redirect + flash）の境界のみ検証する。
  test "一般ユーザーの参照肥料作成失敗は redirect + flash へマッピングされる" do
    sign_in_as @user

    post fertilizes_path, params: { fertilize: {
      name: "参照肥料", n: 20.0, p: 10.0, k: 10.0, is_reference: true
    } }

    assert_redirected_to fertilizes_path
    assert_equal I18n.t("fertilizes.flash.reference_only_admin"), flash[:alert]
  end

  test "update の権限拒否は redirect + flash へマッピングされる" do
    sign_in_as @user
    old_n = @reference_fertilize.n

    patch fertilize_path(@reference_fertilize), params: { fertilize: {
      name: @reference_fertilize.name,
      n: 30.0
    } }

    assert_redirected_to fertilizes_path
    assert_equal I18n.t("fertilizes.flash.no_permission"), flash[:alert]

    @reference_fertilize.reload
    assert_equal old_n, @reference_fertilize.n
  end

  test "一般ユーザーの is_reference 変更失敗は redirect + flash へマッピングされる" do
    sign_in_as @user
    patch fertilize_path(@user_fertilize), params: { fertilize: {
      name: @user_fertilize.name,
      is_reference: true
    } }

    assert_redirected_to fertilize_path(@user_fertilize)
    assert_equal I18n.t("fertilizes.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    fertilize = create(:fertilize, :user_owned, user: @user, name: "テスト肥料")

    assert_difference -> { Fertilize.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete fertilize_path(fertilize)
        assert_redirected_to fertilizes_path
      end
    end

    expected_notice = I18n.t("deletion_undo.redirect_notice", resource: fertilize.name)
    assert_equal expected_notice, flash[:notice]
  end

  test "一般ユーザーは参照肥料をdestroyできない" do
    sign_in_as @user
    reference_fertilize = create(:fertilize, is_reference: true, user_id: nil)

    assert_no_difference("Fertilize.count") do
      delete fertilize_path(reference_fertilize)
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t("fertilizes.flash.no_permission"), flash[:alert]
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は FertilizePolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/fertilize_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
