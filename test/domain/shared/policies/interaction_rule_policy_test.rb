# frozen_string_literal: true

require "domain_lib_test_helper"

# InteractionRulePolicy — region / is_reference の認可（admin 限定）はこのポリシーが判定する。
# Controller の strong params では認可しない（mass-assignment 許可のみ）。
class Domain::Shared::Policies::InteractionRulePolicyTest < DomainLibTestCase
  UserDouble = Struct.new(:id, :admin?, keyword_init: true)

  setup do
    @user = UserDouble.new(id: 9, admin?: false)
    @admin = UserDouble.new(id: 1, admin?: true)
  end

  # ---- normalize_attrs_for_create: region 認可 ----

  test "normalize_attrs_for_create は admin の region を保持する" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(
      @admin, { rule_type: "continuous_cultivation", region: "us", is_reference: false }
    )

    assert_equal "us", h[:region]
  end

  test "normalize_attrs_for_create は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(
      @user, { rule_type: "continuous_cultivation", region: "us", is_reference: false }
    )

    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_create は参照ルールを user_id=nil にする" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(
      @admin, { rule_type: "continuous_cultivation", is_reference: true }
    )

    assert h[:is_reference]
    assert_nil h[:user_id]
  end

  test "normalize_attrs_for_create は非参照ルールを呼び出しユーザー所有にする" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(
      @user, { rule_type: "continuous_cultivation", is_reference: false }
    )

    assert_not h[:is_reference]
    assert_equal @user.id, h[:user_id]
  end

  # ---- normalize_attrs_for_update: region 認可 ----

  test "normalize_attrs_for_update は admin の region を保持する" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_update(
      @admin, { is_reference: false }, { region: "in" }
    )

    assert_equal "in", h[:region]
  end

  test "normalize_attrs_for_update は一般ユーザーの region を破棄する" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_update(
      @user, { is_reference: false }, { region: "us" }
    )

    assert_not h.key?(:region)
  end

  test "normalize_attrs_for_update は参照化のとき user_id を nil にする" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_update(
      @admin, { is_reference: false }, { is_reference: true }
    )

    assert_nil h[:user_id]
  end

  test "normalize_attrs_for_update は参照解除のとき user_id を操作ユーザーにする" do
    h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_update(
      @admin, { is_reference: true }, { is_reference: false }
    )

    assert_equal @admin.id, h[:user_id]
  end

  # ---- 閲覧 / 編集可否 ----

  test "view_allowed? は admin と所有者に許可する" do
    assert Domain::Shared::Policies::InteractionRulePolicy.view_allowed?(@admin, is_reference: false, user_id: 999)
    assert Domain::Shared::Policies::InteractionRulePolicy.view_allowed?(@user, is_reference: false, user_id: @user.id)
    assert_not Domain::Shared::Policies::InteractionRulePolicy.view_allowed?(@user, is_reference: false, user_id: 999)
  end

  test "edit_allowed? は一般ユーザーの参照ルール編集を拒否する" do
    assert Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(@admin, is_reference: true, user_id: nil)
    assert_not Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(@user, is_reference: true, user_id: nil)
    assert Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(@user, is_reference: false, user_id: @user.id)
  end
end
