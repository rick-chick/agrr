# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanPhaseBroadcastPayloadMapper
        module_function

        # @param plan [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        # @param progress [Integer]
        # @param phase_message [String, nil]
        def to_port_payload(plan:, progress:, phase_message:)
          phase = plan.optimization_phase
          {
            status: plan.status,
            progress: progress,
            phase: phase,
            phase_message: phase_message,
            message: phase_message,
            message_key: "models.cultivation_plan.phases.#{phase}"
          }
        end
      end
    end
  end
end
