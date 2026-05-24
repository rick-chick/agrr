# frozen_string_literal: true

require "domain_lib_test_helper"

class Domain::Shared::Policies::PesticidePolicyTest < DomainLibTestCase
  UserDouble = Struct.new(:id, :admin?, keyword_init: true)

  setup do
    @user = UserDouble.new(id: 9, admin?: false)
    @admin = UserDouble.new(id: 1, admin?: true)
  end

  test "normalize_attrs_for_create for regular user" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(@user, { name: "P", is_reference: false })

    assert_equal @user.id, h[:user_id]
    assert_equal false, h[:is_reference]
  end

  test "view_allowed? uses referencable rule" do
    refute Domain::Shared::Policies::PesticidePolicy.view_allowed?(@user, is_reference: true, user_id: nil)
    assert Domain::Shared::Policies::PesticidePolicy.view_allowed?(@admin, is_reference: true, user_id: nil)
  end

  # ---- region 認可（admin のみ設定・更新可）----

  test "normalize_attrs_for_create は admin の region を保持する" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(@admin, { region: "us", is_reference: false })
    assert_equal "us", h[:region]
  end

  test "normalize_attrs_for_create は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(@user, { region: "us", is_reference: false })
    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_update は admin の region を保持する" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_update(@admin, { is_reference: false }, { region: "in" })
    assert_equal "in", h[:region]
  end

  test "normalize_attrs_for_update は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_update(@user, { is_reference: false }, { region: "us" })
    assert_not h.key?(:region)
  end
end
