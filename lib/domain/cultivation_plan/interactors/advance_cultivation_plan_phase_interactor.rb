# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class AdvanceCultivationPlanPhaseInteractor
        def initialize(
          cultivation_plan_gateway:,
          translator:,
          phase_broadcast_port:,
          check_optimization_completion_interactor: nil
        )
          @cultivation_plan_gateway = cultivation_plan_gateway
          @translator = translator
          @phase_broadcast_port = phase_broadcast_port
          @check_optimization_completion_interactor = check_optimization_completion_interactor
        end

        def call(input_dto)
          built = Policies::CultivationPlanPhasePolicy.build(
            phase_name: input_dto.phase_name,
            failure_subphase: input_dto.failure_subphase
          )
          attrs = built[:attrs].dup
          if built[:message_key]
            attrs[:optimization_phase_message] = @translator.t(built[:message_key])
          end

          plan = @cultivation_plan_gateway.update(input_dto.plan_id, attrs)

          if built[:broadcast] && input_dto.channel_class
            field_cultivations = @cultivation_plan_gateway.list_by_plan_id(input_dto.plan_id)
            progress = Calculators::CultivationPlanOptimizationProgressCalculator.progress_percent(
              field_cultivations: field_cultivations
            )
            payload = Mappers::CultivationPlanPhaseBroadcastPayloadMapper.to_port_payload(
              plan: plan,
              progress: progress,
              phase_message: plan.optimization_phase_message
            )
            @phase_broadcast_port.broadcast_phase_update(
              plan_id: input_dto.plan_id,
              channel_class: input_dto.channel_class,
              payload: payload
            )
          end

          @check_optimization_completion_interactor&.call(
            Dtos::CultivationPlanCheckOptimizationCompletionInput.new(plan_id: input_dto.plan_id)
          )

          plan
        end
      end
    end
  end
end
