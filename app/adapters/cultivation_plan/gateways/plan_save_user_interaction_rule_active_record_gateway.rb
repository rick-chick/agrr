# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanSaveUserInteractionRuleActiveRecordGateway <
          Domain::CultivationPlan::Gateways::PlanSaveUserInteractionRuleGateway
        def find_by_user_id_and_source_interaction_rule_id(user_id:, source_interaction_rule_id:)
          record = user_interaction_rules_scope(user_id).find_by(
            source_interaction_rule_id: source_interaction_rule_id
          )
          return nil unless record

          interaction_rule_snapshot(record)
        end

        def find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
          user_id:,
          rule_type:,
          source_group:,
          target_group:,
          region:
        )
          record = user_interaction_rules_scope(user_id).find_by(
            rule_type: rule_type,
            source_group: source_group,
            target_group: target_group,
            region: region,
            is_reference: false
          )
          return nil unless record

          interaction_rule_snapshot(record)
        end

        def update(user_id:, interaction_rule_id:, attributes:)
          record = user_interaction_rules_scope(user_id).find_by(id: interaction_rule_id)
          unless record
            raise Domain::Shared::Exceptions::RecordNotFound,
                  "InteractionRule not found: #{interaction_rule_id}"
          end

          unless record.update(attributes)
            raise Domain::Shared::Exceptions::RecordInvalid, record.errors.full_messages.join(", ")
          end

          interaction_rule_snapshot(record)
        end

        def create(user_id:, attributes:)
          user = ::User.find_by(id: user_id)
          unless user
            raise Domain::Shared::Exceptions::RecordNotFound, "User not found: #{user_id}"
          end

          rule = user.interaction_rules.build(attributes)
          unless rule.save
            raise Domain::Shared::Exceptions::RecordInvalid, rule.errors.full_messages.join(", ")
          end

          interaction_rule_snapshot(rule)
        end

        private

        def user_interaction_rules_scope(user_id)
          ::InteractionRule.where(user_id: user_id.to_i, is_reference: false)
        end

        def interaction_rule_snapshot(record)
          Domain::CultivationPlan::Dtos::PlanSaveUserInteractionRuleSnapshot.new(
            id: record.id,
            source_interaction_rule_id: record.source_interaction_rule_id
          )
        end
      end
    end
  end
end
