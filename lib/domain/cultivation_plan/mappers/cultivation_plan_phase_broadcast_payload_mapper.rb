# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanPhaseBroadcastPayloadMapper
        module_function

        # @param plan [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        # @param progress [Integer]
        # @param phase_message [String, nil]
        # Rails-only phases; remap stale rows so Cable does not show task-schedule copy.
        def cable_phase(optimization_phase)
          case optimization_phase
          when "optimization_completed", "task_schedule_generating"
            "optimizing"
          else
            optimization_phase
          end
        end

        def cable_message_key(stored_phase, phase, phase_message)
          if stored_phase == "failed"
            if phase_message.to_s.start_with?("models.cultivation_plan.phase_failed.")
              return phase_message
            end

            return "models.cultivation_plan.phase_failed.default"
          end

          "models.cultivation_plan.phases.#{phase}"
        end

        def to_port_payload(plan:, progress:, phase_message:)
          stored_phase = plan.optimization_phase
          phase = cable_phase(stored_phase)
          phase_message = nil if stored_phase != phase
          {
            status: plan.status,
            progress: progress,
            phase: phase,
            phase_message: phase_message,
            message: phase_message,
            message_key: cable_message_key(stored_phase, phase, phase_message)
          }
        end
      end
    end
  end
end
