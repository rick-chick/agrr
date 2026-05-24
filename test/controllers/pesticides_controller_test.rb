# frozen_string_literal: true

require "test_helper"
require "time"

# 参照農薬の閲覧拒否などは PesticideDetailInteractor 単体で表明。
# ここでは index の表示フィルタと nested 作成の永続化挙動（Interactor 外の境界）を優先する。

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

  test "should create pesticide" do
    assert_difference("Pesticide.count") do
      post pesticides_path, params: { pesticide: {
        name: "テスト農薬",
        active_ingredient: "テスト成分",
        description: "テスト用",
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false
      } }
    end

    assert_redirected_to pesticide_path(Pesticide.last)
    pesticide = Pesticide.last
    assert_equal "テスト農薬", pesticide.name
  end

  test "should create pesticide with usage_constraint" do
    # 現状の Create Interactor は nested attributes を扱わないため Pesticide のみ作成される
    assert_difference("Pesticide.count", 1) do
      post pesticides_path, params: { pesticide: {
        name: "テスト農薬",
        active_ingredient: "テスト成分",
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false,
        pesticide_usage_constraint_attributes: {
          min_temperature: 5.0,
          max_temperature: 35.0,
          max_wind_speed_m_s: 3.0,
          max_application_count: 3,
          harvest_interval_days: 1
        }
      } }
    end

    pesticide = Pesticide.last
    assert_equal "テスト農薬", pesticide.name
  end

  test "should create pesticide with application_detail" do
    # 現状の Create Interactor は nested attributes を扱わないため Pesticide のみ作成される
    assert_difference("Pesticide.count", 1) do
      post pesticides_path, params: { pesticide: {
        name: "テスト農薬",
        active_ingredient: "テスト成分",
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false,
        pesticide_application_detail_attributes: {
          dilution_ratio: "1000倍",
          amount_per_m2: 0.1,
          amount_unit: "ml",
          application_method: "散布"
        }
      } }
    end

    pesticide = Pesticide.last
    assert_equal "テスト農薬", pesticide.name
  end

  test "should update pesticide" do
    # ユーザー農薬を作成
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)

    patch pesticide_path(pesticide), params: { pesticide: {
      name: "更新された農薬名",
      active_ingredient: "更新された成分"
    } }
    assert_redirected_to pesticide_path(pesticide)
    pesticide.reload
    assert_equal "更新された農薬名", pesticide.name
    assert_equal "更新された成分", pesticide.active_ingredient
  end

  test "should update pesticide with usage_constraint" do
    # ユーザー農薬を作成
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
    constraint = create(:pesticide_usage_constraint, pesticide: pesticide, min_temperature: 10.0)

    # 現状の Update Interactor は nested attributes を扱わないため、リダイレクトのみ検証
    patch pesticide_path(pesticide), params: { pesticide: {
      name: pesticide.name,
      pesticide_usage_constraint_attributes: {
        id: constraint.id,
        min_temperature: 5.0
      }
    } }
    assert_redirected_to pesticide_path(pesticide)
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

  test "should allow admin to create reference pesticide" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    assert_difference("Pesticide.count") do
      post pesticides_path, params: { pesticide: {
        name: "参照農薬",
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      } }
    end

    assert_redirected_to pesticide_path(Pesticide.last)
    assert Pesticide.last.is_reference?
  end

  # ========== region 認可 ==========
  #
  # region（admin のみ設定・更新可）の認可は PesticidePolicy.normalize_attrs_for_* が
  # 判定する（Controller の strong params は mass-assignment 許可のみ）。
  #   → test/policies/pesticide_policy_test.rb
  # このため region 系の controller テストは policy テストへ切り離した。
end
