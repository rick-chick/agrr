# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::CropPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for admin with reference crop" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(@admin, { name: "RefCrop", is_reference: true })

    assert h[:is_reference]
    assert_nil h[:user_id]
    assert_equal "RefCrop", h[:name]
  end

  test "normalize_attrs_for_create for admin with user crop (non-reference)" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(@admin, { name: "UserCrop", is_reference: false })

    assert_not h[:is_reference]
    assert_equal @admin.id, h[:user_id]
    assert_equal "UserCrop", h[:name]
  end

  test "normalize_attrs_for_create for regular user always creates non-reference crop owned by user" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(@user, { name: "UserCrop", is_reference: true })

    assert_not h[:is_reference]
    assert_equal @user.id, h[:user_id]
    assert_equal "UserCrop", h[:name]
  end

  test "view_allowed? for admin" do
    assert Domain::Shared::Policies::CropPolicy.view_allowed?(@admin, is_reference: false, user_id: 999)
  end

  test "view_allowed? for reference crop" do
    assert Domain::Shared::Policies::CropPolicy.view_allowed?(@user, is_reference: true, user_id: nil)
  end

  test "view_allowed? for own crop" do
    assert Domain::Shared::Policies::CropPolicy.view_allowed?(@user, is_reference: false, user_id: @user.id)
  end

  test "view_allowed? denies other user non-reference crop" do
    assert_not Domain::Shared::Policies::CropPolicy.view_allowed?(@user, is_reference: false, user_id: @user.id + 999)
  end

  test "edit_allowed? for own non-reference" do
    assert Domain::Shared::Policies::CropPolicy.edit_allowed?(@user, is_reference: false, user_id: @user.id)
  end

  test "ReferencableResourcePolicy visible_for_user? matches referencable list rule" do
    assert Domain::Shared::Policies::ReferencableResourcePolicy.visible_for_user?(@admin, is_reference: true, user_id: nil)
    assert Domain::Shared::Policies::ReferencableResourcePolicy.visible_for_user?(@user, is_reference: false, user_id: @user.id)
  end

  # ---- region 認可（admin のみ設定・更新可）----

  test "normalize_attrs_for_create は admin の region を保持する" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(@admin, { region: "us", is_reference: false })
    assert_equal "us", h[:region]
  end

  test "normalize_attrs_for_create は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(@user, { region: "us", is_reference: false })
    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_update は admin の region を保持する" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_update(@admin, { is_reference: false }, { region: "in" })
    assert_equal "in", h[:region]
  end

  test "normalize_attrs_for_update は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_update(@user, { is_reference: false }, { region: "us" })
    assert_not h.key?(:region)
  end
end
