# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemUpdateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(plan:, item_id:, attributes:)
          payload = @gateway.update_item_for_plan!(plan, item_id, attributes)
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
