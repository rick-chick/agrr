# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Mappers
      class InteractionRuleMapper
        def self.interaction_rule_entity_from_record(record)
          Domain::InteractionRule::Entities::InteractionRuleEntity.new(
            id: record.id,
            user_id: record.user_id,
            rule_type: record.rule_type,
            source_group: record.source_group,
            target_group: record.target_group,
            impact_ratio: record.impact_ratio,
            is_directional: record.is_directional,
            description: record.description,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
