# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class TaskScheduleItemCreateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(plan:, attributes:)
          item = @gateway.create_item!(plan, attributes)
          @output_port.on_created(@gateway.serialize_item(item))
        rescue ActiveRecord::RecordInvalid => e
          @output_port.on_record_invalid(e.record, e.message)
        rescue ActiveRecord::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
