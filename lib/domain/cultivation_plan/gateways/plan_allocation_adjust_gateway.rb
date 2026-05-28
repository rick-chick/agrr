# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustGateway
        # @raise [Domain::CultivationPlan::Errors::AdjustExecutionError] when agrr adjust execution fails
        def adjust(current_allocation:, moves:, fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
