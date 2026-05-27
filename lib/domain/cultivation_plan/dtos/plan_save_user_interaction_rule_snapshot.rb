# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveUserInteractionRuleGateway の find / create / update 戻り値。
      class PlanSaveUserInteractionRuleSnapshot
        attr_reader :id, :source_interaction_rule_id

        # @param id [Integer, #to_i]
        # @param source_interaction_rule_id [Integer, nil]
        def initialize(id:, source_interaction_rule_id: nil)
          @id = id.to_i
          @source_interaction_rule_id =
            source_interaction_rule_id.nil? ? nil : source_interaction_rule_id.to_i
          freeze
        end
      end
    end
  end
end
