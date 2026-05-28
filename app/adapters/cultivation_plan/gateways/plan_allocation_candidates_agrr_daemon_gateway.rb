# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      # PlanAllocationCandidatesGateway の agrr daemon 実装（AR は使わない）。
      class PlanAllocationCandidatesAgrrDaemonGateway < Domain::CultivationPlan::Gateways::PlanAllocationCandidatesGateway
        def initialize
          @inner = ::Adapters::Agrr::Gateways::CandidatesDaemonGateway.new
        end

        def candidates(current_allocation:, fields:, crops:, target_crop:, weather_data:, planning_start:, planning_end:, interaction_rules: nil)
          @inner.candidates(
            current_allocation: current_allocation,
            fields: fields,
            crops: crops,
            target_crop: target_crop,
            weather_data: weather_data,
            planning_start: planning_start,
            planning_end: planning_end,
            interaction_rules: interaction_rules
          )
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::NoAllocationCandidatesError => e
          raise Domain::CultivationPlan::Errors::AllocationNoCandidatesError, e.message
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
               ::Adapters::Agrr::Gateways::BaseGatewayV2::ParseError => e
          raise Domain::CultivationPlan::Errors::AllocationExecutionError, e.message
        end
      end
    end
  end
end
