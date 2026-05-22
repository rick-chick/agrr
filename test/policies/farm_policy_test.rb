# frozen_string_literal: true

require "test_helper"

class Domain::Shared::Policies::FarmPolicyTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @admin = create(:user, :admin)
  end

  test "normalize_attrs_for_create sets user and non-reference" do
    h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_create(@user, { name: "F", region: "jp" })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
    assert_equal "F", h[:name]
  end

  test "view_allowed? for admin" do
    assert Domain::Shared::Policies::FarmPolicy.view_allowed?(@admin, is_reference: false, user_id: 999)
  end

  test "view_allowed? for reference farm" do
    assert Domain::Shared::Policies::FarmPolicy.view_allowed?(@user, is_reference: true, user_id: nil)
  end

  test "edit_allowed? for own non-reference" do
    assert Domain::Shared::Policies::FarmPolicy.edit_allowed?(@user, is_reference: false, user_id: @user.id)
  end

  # ---- region 認可（admin のみ設定・更新可）----

  test "normalize_attrs_for_create は admin の region を保持する" do
    h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_create(@admin, { name: "F", region: "us" })
    assert_equal "us", h[:region]
  end

  test "normalize_attrs_for_create は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_create(@user, { name: "F", region: "us" })
    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_update は admin の region を保持する" do
    h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_update(@admin, {}, { region: "in" })
    assert_equal "in", h[:region]
  end

  test "normalize_attrs_for_update は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::FarmPolicy.normalize_attrs_for_update(@user, {}, { region: "us" })
    assert_not h.key?(:region)
  end
end
