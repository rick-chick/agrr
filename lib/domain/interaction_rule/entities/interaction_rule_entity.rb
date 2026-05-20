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
          raise ArgumentError, "rule_type, source_group, target_group, impact_ratio are required" if Domain::Shared.blank?(rule_type) || Domain::Shared.blank?(source_group) || Domain::Shared.blank?(target_group) || impact_ratio.nil?
          raise ArgumentError, "region must be one of jp, us, in" if Domain::Shared.present?(region) && !%w[jp us in].include?(region)
        end
      end
    end
  end
end
