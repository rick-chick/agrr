# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanAllocationGatewayAdapter < Domain::CultivationPlan::Gateways::PlanAllocationGateway
        def initialize
          @inner = ::Adapters::Agrr::PlanAllocationGatewayAdapter.new
        end

        def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          @inner.allocate(
            fields: fields,
            crops: crops,
            weather_data: weather_data,
            planning_start: planning_start,
            planning_end: planning_end,
            interaction_rules: interaction_rules,
            objective: objective,
            max_time: max_time,
            enable_parallel: enable_parallel
          )
        rescue ::Agrr::BaseGatewayV2::NoAllocationCandidatesError => e
          raise Domain::CultivationPlan::Errors::AllocationNoCandidatesError, e.message
        rescue ::Agrr::BaseGatewayV2::ExecutionError => e
          raise Domain::CultivationPlan::Errors::AllocationExecutionError, e.message
        end
      end
    end
  end
end
