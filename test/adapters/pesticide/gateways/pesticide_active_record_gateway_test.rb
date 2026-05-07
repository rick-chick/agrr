# frozen_string_literal: true

require "test_helper"

class Adapters::Pesticide::Gateways::PesticideActiveRecordGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::Pesticide::Gateways::PesticideActiveRecordGateway.new(
      deletion_undo_gateway: CompositionRoot.deletion_undo_gateway,
      translator: CompositionRoot.translator
    )
    @user = create(:user)
  end

  test "build_blank_pesticide_for_html_form returns new pesticide with nested builds" do
    p = @gateway.build_blank_pesticide_for_html_form

    assert_instance_of ::Pesticide, p
    assert p.new_record?
    assert p.pesticide_usage_constraint
    assert p.pesticide_usage_constraint.new_record?
    assert p.pesticide_application_detail
    assert p.pesticide_application_detail.new_record?
  end

  test "build_pesticide_for_create_failure_html_form applies attributes on new record" do
    p = @gateway.build_pesticide_for_create_failure_html_form({ name: "tmp-fail", active_ingredient: "X" })

    assert p.new_record?
    assert_equal "tmp-fail", p.name
    assert_equal "X", p.active_ingredient
  end

  test "ensure_nested_associations_for_pesticide_html_form! builds missing nested records" do
    p = ::Pesticide.new(name: "n")
    @gateway.ensure_nested_associations_for_pesticide_html_form!(p)

    assert p.pesticide_usage_constraint
    assert p.pesticide_application_detail
  end

  test "assign_pesticide_attributes_for_html_form! updates in-memory attributes" do
    p = ::Pesticide.new(name: "old")
    @gateway.assign_pesticide_attributes_for_html_form!(p, { name: "new" })

    assert_equal "new", p.name
  end

  test "accessible crops and pests scopes delegate to PesticideAssociationPolicy" do
    crops_gw = @gateway.accessible_crops_scope_for_pesticide_html_form(user: @user)
    pests_gw = @gateway.accessible_pests_scope_for_pesticide_html_form(user: @user)
    crops_po = PesticideAssociationPolicy.accessible_crops_scope(@user)
    pests_po = PesticideAssociationPolicy.accessible_pests_scope(@user)

    assert_equal crops_po.to_sql, crops_gw.to_sql
    assert_equal pests_po.to_sql, pests_gw.to_sql
  end
end
