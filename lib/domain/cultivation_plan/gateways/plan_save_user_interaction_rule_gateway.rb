# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanSaveUserInteractionRuleGateway
        # @return [Dtos::PlanSaveUserInteractionRuleSnapshot, nil]
        def find_by_user_id_and_source_interaction_rule_id(user_id:, source_interaction_rule_id:)
          raise NotImplementedError
        end

        # @return [Dtos::PlanSaveUserInteractionRuleSnapshot, nil]
        def find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
          user_id:,
          rule_type:,
          source_group:,
          target_group:,
          region:
        )
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param interaction_rule_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserInteractionRuleSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def update(user_id:, interaction_rule_id:, attributes:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserInteractionRuleSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end
      end
    end
  end
end
