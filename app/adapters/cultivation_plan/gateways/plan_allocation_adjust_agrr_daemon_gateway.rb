# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PlanAllocationAdjustAgrrDaemonGateway < Domain::CultivationPlan::Gateways::PlanAllocationAdjustGateway
        def initialize
          @inner = ::Adapters::Agrr::Gateways::AdjustDaemonGateway.new
        end

        def adjust(current_allocation:, moves:, fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          @inner.adjust(
            current_allocation: current_allocation,
            moves: moves,
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
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError => e
          raise Domain::CultivationPlan::Errors::AdjustExecutionError, e.message
        end
      end
    end
  end
end
