# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::PestPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create for regular user forces non-reference" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(@user, { name: "P", is_reference: true })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "view_allowed? for reference pest" do
    assert Domain::Shared::Policies::PestPolicy.view_allowed?(@user, is_reference: true, user_id: nil)
  end

  test "selectable_list_filter is reference_or_owned for regular user" do
    filter = Domain::Shared::Policies::PestPolicy.selectable_list_filter(@user)

    assert_equal :reference_or_owned, filter.mode
    assert_equal @user.id, filter.user_id
  end

  test "selectable_for_user? allows reference and own pests" do
    assert Domain::Shared::Policies::PestPolicy.selectable_for_user?(@user, is_reference: true, user_id: nil)
    assert Domain::Shared::Policies::PestPolicy.selectable_for_user?(@user, is_reference: false, user_id: @user.id)
    assert_not Domain::Shared::Policies::PestPolicy.selectable_for_user?(@user, is_reference: false, user_id: @user.id + 1)
  end

  # ---- region 認可（admin のみ設定・更新可）----

  test "normalize_attrs_for_create は admin の region を保持する" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(@admin, { region: "us", is_reference: false })
    assert_equal "us", h[:region]
  end

  test "normalize_attrs_for_create は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(@user, { region: "us", is_reference: false })
    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_update は admin の region を保持する" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(@admin, { is_reference: false }, { region: "in" })
    assert_equal "in", h[:region]
  end

  test "normalize_attrs_for_update は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(@user, { is_reference: false }, { region: "us" })
    assert_not h.key?(:region)
  end
end
