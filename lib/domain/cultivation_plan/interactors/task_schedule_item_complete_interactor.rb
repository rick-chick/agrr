# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCompleteInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(user_id:, plan_id:, item_id:, actual_date:, actual_notes:, completed_at:)
          payload = @gateway.complete_item_for_plan!(
            user_id,
            plan_id,
            item_id,
            actual_date: actual_date,
            actual_notes: actual_notes,
            completed_at: completed_at
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
