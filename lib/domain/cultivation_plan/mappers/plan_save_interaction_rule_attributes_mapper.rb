# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveInteractionRuleAttributesMapper
        # @param row [Dtos::PublicPlanSaveInteractionRuleReferenceRow]
        # @return [Hash]
        def self.attributes_for_create(row:)
          {
            rule_type: row.rule_type,
            source_group: row.source_group,
            target_group: row.target_group,
            impact_ratio: row.impact_ratio.to_f,
            is_directional: row.is_directional,
            region: row.region,
            description: row.description,
            is_reference: false,
            source_interaction_rule_id: row.reference_interaction_rule_id
          }
        end
      end
    end
  end
end
