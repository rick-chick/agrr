# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCompleteInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(plan:, item_id:, actual_date:, actual_notes:, completed_at:)
          item = @gateway.find_item_for_plan(plan, item_id)
          unless item
            @output_port.on_not_found
            return
          end

          @gateway.complete_item!(
            item,
            actual_date: actual_date,
            actual_notes: actual_notes,
            completed_at: completed_at
          )
          @output_port.on_success(@gateway.serialize_item(item.reload))
        rescue ActiveRecord::RecordInvalid => e
          @output_port.on_record_invalid(e.record, e.message)
        rescue ActiveRecord::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
