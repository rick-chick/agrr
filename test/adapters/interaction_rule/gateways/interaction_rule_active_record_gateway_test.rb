# frozen_string_literal: true

require "test_helper"

module Adapters
  module InteractionRule
    module Gateways
      class InteractionRuleActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          deletion_undo_gateway = mock("deletion_undo_gateway")
          @gateway = Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new(
            deletion_undo_gateway: deletion_undo_gateway,
            translator: Adapters::Shared::Ports::RailsTranslatorAdapter.new
          )
          ::InteractionRule.delete_all # テスト前にデータをクリーンアップ
        end

        test "should find by id and return entity" do
          record = create(:interaction_rule, :reference, rule_type: "continuous_cultivation", region: "jp")
          entity = @gateway.find_by_id(record.id)
          assert_not_nil entity
          assert_equal record.id, entity.id
          assert_equal "continuous_cultivation", entity.rule_type
          assert_equal "jp", entity.region
        end

        test "should raise when not found" do
          assert_raises(Domain::Shared::Exceptions::RecordNotFound) { @gateway.find_by_id(9999) }
        end

        test "should create and return entity" do
          create_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInput.new(
            rule_type: "continuous_cultivation",
            source_group: "ナス科",
            target_group: "ナス科",
            impact_ratio: 0.7,
            region: "us",
            is_reference: true
          )
          entity = @gateway.create(create_dto)
          assert_not_nil entity
          assert_equal "continuous_cultivation", entity.rule_type
          assert_equal "us", entity.region
          assert entity.reference?
          persisted = ::InteractionRule.find_by(rule_type: "continuous_cultivation", region: "us")
          assert_not_nil persisted
        end

        test "should raise when create fails validation - invalid region" do
          create_dto = Domain::InteractionRule::Dtos::InteractionRuleCreateInput.new(
            rule_type: "continuous_cultivation",
            source_group: "ナス科",
            target_group: "ナス科",
            impact_ratio: 0.7,
            region: "invalid",
            is_reference: true
          )
          assert_raises(Domain::Shared::Exceptions::RecordInvalid) { @gateway.create(create_dto) }
        end

        test "should update and return entity" do
          record = create(:interaction_rule, :reference, rule_type: "continuous_cultivation", region: "jp")
          update_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(
            id: record.id,
            region: "us"
          )
          entity = @gateway.update(record.id, update_dto)
          assert_not_nil entity
          assert_equal record.id, entity.id
          assert_equal "us", entity.region
          assert_equal "continuous_cultivation", entity.rule_type # unchanged
          record.reload
          assert_equal "us", record.region
        end

        test "should raise when update fails validation - invalid region" do
          record = create(:interaction_rule, :reference, region: "jp")
          update_dto = Domain::InteractionRule::Dtos::InteractionRuleUpdateInput.new(
            id: record.id,
            region: "invalid"
          )
          assert_raises(Domain::Shared::Exceptions::RecordInvalid) { @gateway.update(record.id, update_dto) }
        end

        test "list_index_for_filter returns scoped entities for non-admin" do
          user = create(:user, admin: false)
          my_rule = create(:interaction_rule, user: user, is_reference: false, region: "jp")
          create(:interaction_rule, :reference, region: "jp")
          filter = Domain::Shared::Policies::InteractionRulePolicy.index_list_filter(user)
          entities = @gateway.list_index_for_filter(filter)
          assert_equal 1, entities.size
          assert_equal my_rule.id, entities.first.id
        end

        test "list_index_for_filter for admin includes reference and own rows" do
          admin = create(:user, admin: true)
          ref = create(:interaction_rule, :reference, region: "jp")
          own = create(:interaction_rule, user: admin, is_reference: false, region: "jp")
          other = create(:user)
          create(:interaction_rule, user: other, is_reference: false, region: "jp")

          filter = Domain::Shared::Policies::InteractionRulePolicy.index_list_filter(admin)
          ids = @gateway.list_index_for_filter(filter).map(&:id)

          assert_includes ids, ref.id
          assert_includes ids, own.id
        end

        test "list_by_cultivation_plan_id returns entities for plan farm region" do
          user = create(:user)
          farm = create(:farm, user: user, region: "jp")
          plan = create(:cultivation_plan, user: user, farm: farm)
          ref_rule = create(:interaction_rule, :reference, region: "jp")
          create(:interaction_rule, :reference, region: "us")

          entities = @gateway.list_by_cultivation_plan_id(cultivation_plan_id: plan.id)

          assert_equal 1, entities.size
          assert_equal ref_rule.id, entities.first.id
          assert entities.first.is_a?(Domain::InteractionRule::Entities::InteractionRuleEntity)
        end
      end
    end
  end
end
