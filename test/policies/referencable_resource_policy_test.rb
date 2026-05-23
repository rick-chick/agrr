# frozen_string_literal: true

require "test_helper"

# 参照可能マスタ（crop / fertilize / pesticide / pest / agricultural_task）共通の
# 認可・正規化ルール。各 *Policy はこのモジュールへ委譲する。
class Domain::Shared::Policies::ReferencableResourcePolicyTest < ActiveSupport::TestCase
  Policy = Domain::Shared::Policies::ReferencableResourcePolicy
  UserDouble = Struct.new(:id, :admin?, keyword_init: true)

  setup do
    @user = UserDouble.new(id: 9, admin?: false)
    @admin = UserDouble.new(id: 1, admin?: true)
  end

  # ---- reference_assignment_allowed? ----

  test "reference_assignment_allowed? は非参照なら誰でも true" do
    assert Policy.reference_assignment_allowed?(@user, is_reference: false)
  end

  test "reference_assignment_allowed? は参照付与を admin のみ許可する" do
    assert Policy.reference_assignment_allowed?(@admin, is_reference: true)
    assert_not Policy.reference_assignment_allowed?(@user, is_reference: true)
  end

  # ---- reference_flag_change_allowed? ----

  test "reference_flag_change_allowed? は変更なし（requested == current）なら true" do
    assert Policy.reference_flag_change_allowed?(@user, requested: false, current: false)
    assert Policy.reference_flag_change_allowed?(@user, requested: true, current: true)
  end

  test "reference_flag_change_allowed? はフラグ変更を admin のみ許可する" do
    assert Policy.reference_flag_change_allowed?(@admin, requested: true, current: false)
    assert_not Policy.reference_flag_change_allowed?(@user, requested: true, current: false)
  end

  # ---- normalize_referencable_attrs_for_create ----

  test "create 正規化: admin の参照レコードは user_id=nil / is_reference=true" do
    h = Policy.normalize_referencable_attrs_for_create(@admin, { is_reference: true })
    assert_nil h[:user_id]
    assert_equal true, h[:is_reference]
  end

  test "create 正規化: admin の非参照レコードは呼び出しユーザー所有" do
    h = Policy.normalize_referencable_attrs_for_create(@admin, { is_reference: false })
    assert_equal @admin.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "create 正規化: 一般ユーザーは常に非参照・自身所有へ強制される" do
    h = Policy.normalize_referencable_attrs_for_create(@user, { is_reference: true })
    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "create 正規化: region は admin のみ保持、一般ユーザーは破棄" do
    assert_equal "us", Policy.normalize_referencable_attrs_for_create(@admin, { region: "us" })[:region]
    assert_not Policy.normalize_referencable_attrs_for_create(@user, { region: "us" }).key?(:region)
  end

  test "create 正規化: admin_forced は admin と同等に扱う" do
    h = Policy.normalize_referencable_attrs_for_create(@user, { is_reference: true, region: "us" }, admin_forced: true)
    assert_equal true, h[:is_reference]
    assert_nil h[:user_id]
    assert_equal "us", h[:region]
  end

  # ---- normalize_referencable_attrs_for_update ----

  test "update 正規化: region は admin のみ保持、一般ユーザーは破棄" do
    assert_equal "in", Policy.normalize_referencable_attrs_for_update(@admin, { is_reference: false }, { region: "in" })[:region]
    assert_not Policy.normalize_referencable_attrs_for_update(@user, { is_reference: false }, { region: "us" }).key?(:region)
  end

  test "update 正規化: 参照化は user_id=nil、参照解除は操作ユーザーを設定" do
    to_ref = Policy.normalize_referencable_attrs_for_update(@admin, { is_reference: false }, { is_reference: true })
    assert_nil to_ref[:user_id]
    assert_equal true, to_ref[:is_reference]

    from_ref = Policy.normalize_referencable_attrs_for_update(@admin, { is_reference: true }, { is_reference: false })
    assert_equal @admin.id, from_ref[:user_id]
    assert_equal false, from_ref[:is_reference]
  end

  test "update 正規化: is_reference に変更が無ければそのキーを落とす" do
    h = Policy.normalize_referencable_attrs_for_update(@admin, { is_reference: false }, { is_reference: false, name: "x" })
    assert_not h.key?(:is_reference)
    assert_equal "x", h[:name]
  end

  # ---- HTML display flags ----

  test "show_reference_badge? は admin かつ参照レコードのみ true" do
    assert Policy.show_reference_badge?(@admin, is_reference: true)
    assert_not Policy.show_reference_badge?(@user, is_reference: true)
    assert_not Policy.show_reference_badge?(@admin, is_reference: false)
  end

  test "show_edit_actions? は参照は admin のみ、非参照は所有者または admin" do
    assert Policy.show_edit_actions?(@admin, is_reference: true, user_id: nil)
    assert_not Policy.show_edit_actions?(@user, is_reference: true, user_id: nil)

    assert Policy.show_edit_actions?(@user, is_reference: false, user_id: @user.id)
    assert_not Policy.show_edit_actions?(@user, is_reference: false, user_id: @user.id + 1)
    assert Policy.show_edit_actions?(@admin, is_reference: false, user_id: 99)
  end

  test "show_delete_task_schedule_blueprint_button? は admin または非参照所有者" do
    assert Policy.show_delete_task_schedule_blueprint_button?(@admin, crop_is_reference: true, crop_user_id: nil)
    assert Policy.show_delete_task_schedule_blueprint_button?(@user, crop_is_reference: false, crop_user_id: @user.id)
    assert_not Policy.show_delete_task_schedule_blueprint_button?(@user, crop_is_reference: true, crop_user_id: nil)
  end
end
