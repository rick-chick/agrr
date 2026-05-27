# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserInteractionRuleActiveRecordGatewayTest < ActiveSupport::TestCase
        setup do
          @gateway = PlanSaveUserInteractionRuleActiveRecordGateway.new
          @user = User.create!(
            email: "plan-save-ir-#{SecureRandom.hex(4)}@example.com",
            name: "IR GW User",
            google_id: "plan-save-ir-#{SecureRandom.hex(8)}"
          )
          @reference = ::InteractionRule.create!(
            user: nil,
            rule_type: "continuous_cultivation",
            source_group: "GroupA",
            target_group: "GroupB",
            impact_ratio: 0.5,
            is_directional: true,
            is_reference: true,
            region: "jp"
          )
        end

        test "find_by_user_id_and_source_interaction_rule_id returns nil when missing" do
          assert_nil @gateway.find_by_user_id_and_source_interaction_rule_id(
            user_id: @user.id,
            source_interaction_rule_id: @reference.id
          )
        end

        test "create and find_by_source round-trip" do
          created = @gateway.create(
            user_id: @user.id,
            attributes: {
              rule_type: "continuous_cultivation",
              source_group: "GroupA",
              target_group: "GroupB",
              impact_ratio: 0.5,
              is_directional: true,
              region: "jp",
              is_reference: false,
              source_interaction_rule_id: @reference.id
            }
          )

          found = @gateway.find_by_user_id_and_source_interaction_rule_id(
            user_id: @user.id,
            source_interaction_rule_id: @reference.id
          )

          assert_equal created.id, found.id
          assert_equal @reference.id, found.source_interaction_rule_id
        end

        test "find_by_natural_key fields returns existing user rule" do
          rule = @user.interaction_rules.create!(
            rule_type: "continuous_cultivation",
            source_group: "GroupX",
            target_group: "GroupY",
            impact_ratio: 0.4,
            is_directional: true,
            is_reference: false,
            region: "jp"
          )

          found = @gateway.find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
            user_id: @user.id,
            rule_type: "continuous_cultivation",
            source_group: "GroupX",
            target_group: "GroupY",
            region: "jp"
          )

          assert_equal rule.id, found.id
        end

        test "update sets source_interaction_rule_id" do
          rule = @user.interaction_rules.create!(
            rule_type: "continuous_cultivation",
            source_group: "GroupX",
            target_group: "GroupY",
            impact_ratio: 0.4,
            is_directional: true,
            is_reference: false,
            region: "jp"
          )

          updated = @gateway.update(
            user_id: @user.id,
            interaction_rule_id: rule.id,
            attributes: { source_interaction_rule_id: @reference.id }
          )

          assert_equal @reference.id, updated.source_interaction_rule_id
          assert_equal @reference.id, rule.reload.source_interaction_rule_id
        end
      end
    end
  end
end
