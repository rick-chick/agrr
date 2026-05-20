# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCompleteInteractor
        def initialize(output_port:, gateway:, clock:)
          @output_port = output_port
          @gateway = gateway
          @clock = clock
        end

        def call(user_id:, plan_id:, item_id:, completion_params:)
          input = Domain::CultivationPlan::Dtos::TaskScheduleItemCompleteInput.from_completion_params(
            completion_params,
            clock: @clock
          )
          payload = @gateway.complete_item_for_plan!(
            user_id,
            plan_id,
            item_id,
            actual_date: input.actual_date,
            actual_notes: input.actual_notes,
            completed_at: input.completed_at
          )
          @output_port.on_success(payload)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_record_invalid(
            errors: Domain::Shared::ValidationErrorHash.from(e.errors),
            fallback_message: e.message
          )
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
