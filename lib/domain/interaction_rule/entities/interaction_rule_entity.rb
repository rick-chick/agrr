# frozen_string_literal: true

module Domain
  module InteractionRule
    module Entities
      class InteractionRuleEntity
        attr_reader :id, :user_id, :rule_type, :source_group, :target_group, :impact_ratio,
                    :is_directional, :description, :region, :is_reference, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @rule_type = attributes[:rule_type]
          @source_group = attributes[:source_group]
          @target_group = attributes[:target_group]
          @impact_ratio = attributes[:impact_ratio]
          @is_directional = attributes[:is_directional]
          @description = attributes[:description]
          @region = attributes[:region]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def self.from_model(record)
          new(
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

        def reference?
          !!is_reference
        end

        def to_hash
          {
            id: id,
            user_id: user_id,
            rule_type: rule_type,
            source_group: source_group,
            target_group: target_group,
            impact_ratio: impact_ratio,
            is_directional: is_directional,
            description: description,
            region: region,
            is_reference: is_reference,
            created_at: created_at,
            updated_at: updated_at
          }
        end

        private

        def validate!
          raise ArgumentError, "rule_type, source_group, target_group, impact_ratio are required" if rule_type.blank? || source_group.blank? || target_group.blank? || impact_ratio.nil?
        end
      end
    end
  end
end
