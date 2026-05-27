# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PublicPlanSaveInteractionRuleReferenceRow
        attr_reader :reference_interaction_rule_id,
                    :rule_type,
                    :source_group,
                    :target_group,
                    :impact_ratio,
                    :is_directional,
                    :region,
                    :description

        # @param reference_interaction_rule_id [Integer, #to_i]
        # @param rule_type [String, #to_s]
        # @param source_group [String, #to_s]
        # @param target_group [String, #to_s]
        # @param impact_ratio [Numeric]
        # @param is_directional [Boolean]
        # @param region [String, nil]
        # @param description [String, nil]
        def initialize(
          reference_interaction_rule_id:,
          rule_type:,
          source_group:,
          target_group:,
          impact_ratio:,
          is_directional:,
          region: nil,
          description: nil
        )
          @reference_interaction_rule_id = reference_interaction_rule_id.to_i
          @rule_type = rule_type.to_s
          @source_group = source_group.to_s
          @target_group = target_group.to_s
          @impact_ratio = impact_ratio
          @is_directional = !!is_directional
          @region = region.nil? ? nil : region.to_s
          @description = description
          freeze
        end
      end
    end
  end
end
