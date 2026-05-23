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

  test "build_blank_pesticide_for_master_form returns new pesticide with nested builds" do
    p = @gateway.build_blank_pesticide_for_master_form

    assert_instance_of ::Pesticide, p
    assert p.new_record?
    assert p.pesticide_usage_constraint
    assert p.pesticide_usage_constraint.new_record?
    assert p.pesticide_application_detail
    assert p.pesticide_application_detail.new_record?
  end

  test "build_pesticide_for_create_failure_master_form applies attributes on new record" do
    p = @gateway.build_pesticide_for_create_failure_master_form({ name: "tmp-fail", active_ingredient: "X" })

    assert p.new_record?
    assert_equal "tmp-fail", p.name
    assert_equal "X", p.active_ingredient
  end

  test "ensure_nested_associations_for_pesticide_master_form! builds missing nested records" do
    p = ::Pesticide.new(name: "n")
    @gateway.ensure_nested_associations_for_pesticide_master_form!(p)

    assert p.pesticide_usage_constraint
    assert p.pesticide_application_detail
  end

  test "assign_pesticide_attributes_for_master_form! updates in-memory attributes" do
    p = ::Pesticide.new(name: "old")
    @gateway.assign_pesticide_attributes_for_master_form!(p, { name: "new" })

    assert_equal "new", p.name
  end

  test "accessible crops and pests relations return correct SQL for regular user" do
    crops_rel = @gateway.send(:accessible_crops_relation_for_pesticide_master_form, user: @user)
    pests_rel = @gateway.send(:accessible_pests_relation_for_pesticide_master_form, user: @user)

    # 通常ユーザー: 自身の非参照レコードのみ
    assert_match(/user_id/, crops_rel.to_sql)
    assert_match(/is_reference/, crops_rel.to_sql)
    assert_match(/user_id/, pests_rel.to_sql)
    assert_match(/is_reference/, pests_rel.to_sql)
  end

  test "list_index_for_filter owned_non_reference returns only that user's non-reference pesticides" do
    user = create(:user)
    other = create(:user)
    crop_u = create(:crop, :user_owned, user: user)
    pest_u = create(:pest, :user_owned, user: user)
    owned = create(:pesticide, :user_owned, user: user, crop: crop_u, pest: pest_u, name: "Mine")
    crop_o = create(:crop, :user_owned, user: other)
    pest_o = create(:pest, :user_owned, user: other)
    create(:pesticide, :user_owned, user: other, crop: crop_o, pest: pest_o, name: "Other")
    crop_r = create(:crop, :reference)
    pest_r = create(:pest, :reference)
    create(:pesticide, :reference, crop: crop_r, pest: pest_r, name: "Ref")

    filter = Domain::Shared::Policies::PesticidePolicy.index_list_filter(user)
    ids = @gateway.list_index_for_filter(filter).map(&:id)

    assert_equal [ owned.id ], ids
  end

  test "list_index_for_filter reference_or_owned includes reference and admin-owned rows" do
    admin = create(:user, admin: true)
    crop_a = create(:crop, :user_owned, user: admin)
    pest_a = create(:pest, :user_owned, user: admin)
    own = create(:pesticide, :user_owned, user: admin, crop: crop_a, pest: pest_a, name: "Admin own")
    crop_r = create(:crop, :reference)
    pest_r = create(:pest, :reference)
    ref = create(:pesticide, :reference, crop: crop_r, pest: pest_r, name: "Ref")
    other = create(:user)
    crop_o = create(:crop, :user_owned, user: other)
    pest_o = create(:pest, :user_owned, user: other)
    other_pesticide = create(:pesticide, :user_owned, user: other, crop: crop_o, pest: pest_o, name: "Other")

    filter = Domain::Shared::Policies::PesticidePolicy.index_list_filter(admin)
    ids = @gateway.list_index_for_filter(filter).map(&:id)

    assert_includes ids, ref.id
    assert_includes ids, own.id
    assert_not_includes ids, other_pesticide.id
  end
end
