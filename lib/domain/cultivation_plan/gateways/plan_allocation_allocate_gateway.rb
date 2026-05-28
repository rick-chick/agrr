# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanAllocationAllocateGateway
        # @raise [Domain::CultivationPlan::Errors::AllocationNoCandidatesError]
        # @raise [Domain::CultivationPlan::Errors::AllocationExecutionError]
        def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
