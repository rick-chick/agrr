# frozen_string_literal: true

require "test_helper"
require "time"

# HTML 応答形（redirect / 一覧描画）の境界のみ。認可・永続化の網羅は
# test/domain/pesticide/interactors/* と test/controllers/api/v1/masters/pesticides_controller_test.rb。

class PesticidesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    sign_in_as @user
    @crop = create(:crop, :reference)
    @pest = create(:pest)
    @pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true)
  end

  # ========== index アクションのテスト ==========

  test "一般ユーザーのindexは自身の非参照農薬のみ表示" do
    user_pesticide = create(:pesticide, :user_owned, user: @user, is_reference: false, name: "ユーザー農薬")
    other_user = create(:user)
    other_pesticide = create(:pesticide, :user_owned, user: other_user, is_reference: false, name: "他人農薬")
    reference_pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true, user_id: nil, name: "参照農薬")

    get pesticides_path
    assert_response :success

    body = response.body
    assert_includes body, user_pesticide.name
    refute_includes body, other_pesticide.name
    refute_includes body, reference_pesticide.name
  end

  test "管理者のindexは自身の農薬と参照農薬を表示し他人の農薬は表示しない" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    admin_pesticide = create(:pesticide, :user_owned, user: admin_user, is_reference: false, name: "管理者農薬")
    other_user = create(:user)
    other_pesticide = create(:pesticide, :user_owned, user: other_user, is_reference: false, name: "他人農薬")
    reference_pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true, user_id: nil, name: "参照農薬")

    get pesticides_path
    assert_response :success

    body = response.body
    assert_includes body, admin_pesticide.name
    assert_includes body, reference_pesticide.name
    refute_includes body, other_pesticide.name
  end

  test "create は redirect する（配線）" do
    assert_difference("Pesticide.count") do
      post pesticides_path, params: { pesticide: {
        name: "テスト農薬",
        active_ingredient: "テスト成分",
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false
      } }
    end

    assert_redirected_to pesticide_path(Pesticide.last)
  end

  # is_reference（admin のみ設定・変更可）の認可は PesticideCreate/UpdateInteractor が
  # 判定する → test/domain/pesticide/interactors/pesticide_{create,update}_interactor_test.rb。
  # 以下の controller テストは認可失敗の HTTP 応答（redirect + flash）の境界のみ検証する。
  test "一般ユーザーの is_reference 変更失敗は redirect + flash へマッピングされる" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, is_reference: false)

    patch pesticide_path(pesticide), params: { pesticide: {
      name: pesticide.name,
      active_ingredient: pesticide.active_ingredient,
      is_reference: true
    } }

    assert_redirected_to pesticide_path(pesticide)
    assert_equal I18n.t("pesticides.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "作成時に必須項目が欠けていると一覧へ redirect する" do
    assert_no_difference("Pesticide.count") do
      post pesticides_path, params: { pesticide: {
        name: "",
        crop_id: @crop.id,
        pest_id: @pest.id
      } }
    end

    assert_redirected_to pesticides_path
    assert flash[:alert].present?
  end

  test "update時に必須項目が欠けていると詳細へ redirect する" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "元の名前")
    original_name = pesticide.name

    patch pesticide_path(pesticide), params: { pesticide: {
      name: ""
    } }

    assert_redirected_to pesticide_path(pesticide)
    assert flash[:alert].present?

    pesticide.reload
    assert_equal original_name, pesticide.name
  end

  test "should not update reference pesticide as non-admin" do
    patch pesticide_path(@pesticide), params: { pesticide: {
      name: "更新された名前"
    } }
    assert_redirected_to pesticides_path
    assert_equal I18n.t("pesticides.flash.no_permission"), flash[:alert]

    @pesticide.reload
    assert_not_equal "更新された名前", @pesticide.name
  end

  test "一般ユーザーの参照農薬作成失敗は redirect + flash へマッピングされる" do
    post pesticides_path, params: { pesticide: {
      name: "参照農薬",
      crop_id: @crop.id,
      pest_id: @pest.id,
      is_reference: true
    } }

    assert_redirected_to pesticides_path
    assert_equal I18n.t("pesticides.flash.reference_only_admin"), flash[:alert]
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は PesticidePolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/pesticide_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
