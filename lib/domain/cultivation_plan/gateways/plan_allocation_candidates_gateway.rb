# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanAllocationCandidatesGateway
        # @return [Array<Hash>] 候補（:field_id, :start_date, :profit 等）
        # @raise [Domain::CultivationPlan::Errors::AllocationNoCandidatesError]
        # @raise [Domain::CultivationPlan::Errors::AllocationExecutionError]
        def candidates(current_allocation:, fields:, crops:, target_crop:, weather_data:, planning_start:, planning_end:, interaction_rules: nil)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
