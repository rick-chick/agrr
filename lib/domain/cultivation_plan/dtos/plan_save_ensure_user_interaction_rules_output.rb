# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserInteractionRulesOutput
        attr_reader :user_interaction_rule_ids, :skipped_interaction_rule_ids

        # @param user_interaction_rule_ids [Array<Integer>]
        # @param skipped_interaction_rule_ids [Array<Integer>]
        def initialize(user_interaction_rule_ids:, skipped_interaction_rule_ids: [])
          @user_interaction_rule_ids = Array(user_interaction_rule_ids).map(&:to_i).freeze
          @skipped_interaction_rule_ids = Array(skipped_interaction_rule_ids).map(&:to_i).freeze
          freeze
        end
      end
    end
  end
end
