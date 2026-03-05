# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleInteractor < Domain::DeletionUndo::Ports::DeletionUndoScheduleInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          raise ArgumentError, 'record must be persisted' unless input_dto.record&.persisted?

          event = @gateway.schedule(
            record: input_dto.record,
            actor: input_dto.actor,
            toast_message: input_dto.toast_message,
            auto_hide_after: input_dto.auto_hide_after,
            metadata: input_dto.metadata
          )

          @output_port.on_success(event)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end