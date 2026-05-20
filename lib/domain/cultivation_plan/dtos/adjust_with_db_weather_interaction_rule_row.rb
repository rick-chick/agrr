# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr interaction rule 1 行。
      class AdjustWithDbWeatherInteractionRuleRow
        attr_reader :rule_id, :rule_type, :source_group, :target_group,
                    :impact_ratio, :is_directional, :description

        def initialize(rule_id:, rule_type:, source_group:, target_group:,
                       impact_ratio:, is_directional:, description:)
          @rule_id = rule_id
          @rule_type = rule_type
          @source_group = source_group
          @target_group = target_group
          @impact_ratio = impact_ratio
          @is_directional = is_directional
          @description = description
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherInteractionRuleRow]
        def self.from_hash(h)
          sym = Domain::Shared.symbolize_keys(h.to_hash)
          new(
            rule_id: sym.fetch(:rule_id),
            rule_type: sym.fetch(:rule_type),
            source_group: sym.fetch(:source_group),
            target_group: sym.fetch(:target_group),
            impact_ratio: sym.fetch(:impact_ratio),
            is_directional: sym.fetch(:is_directional),
            description: sym.fetch(:description)
          )
        end
      end
    end
  end
end
