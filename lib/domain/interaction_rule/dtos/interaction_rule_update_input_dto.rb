# frozen_string_literal: true

module Domain
  module InteractionRule
    module Dtos
      class InteractionRuleUpdateInputDto
        attr_reader :id, :rule_type, :source_group, :target_group, :impact_ratio,
                    :is_directional, :description, :region

        def initialize(id:, rule_type: nil, source_group: nil, target_group: nil, impact_ratio: nil,
                       is_directional: nil, description: nil, region: nil)
          @id = id
          @rule_type = rule_type
          @source_group = source_group
          @target_group = target_group
          @impact_ratio = impact_ratio
          @is_directional = is_directional
          @description = description
          @region = region
        end

        def self.from_hash(hash, rule_id)
          pp = hash[:interaction_rule] || hash
          new(
            id: rule_id,
            rule_type: pp[:rule_type],
            source_group: pp[:source_group],
            target_group: pp[:target_group],
            impact_ratio: pp[:impact_ratio],
            is_directional: pp[:is_directional],
            description: pp[:description],
            region: pp[:region]
          )
        end
      end
    end
  end
end
