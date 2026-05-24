# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      module CultivationPlanOptimizationCompletePolicy
        module_function

        # @param plan_status [String]
        # @param field_cultivation_statuses [Array<String>]
        def should_mark_plan_completed?(plan_status:, field_cultivation_statuses:)
          return false unless plan_status.to_s == "optimizing"
          return false if field_cultivation_statuses.empty?

          field_cultivation_statuses.all? { |s| s.to_s == "completed" }
        end
      end
    end
  end
end
