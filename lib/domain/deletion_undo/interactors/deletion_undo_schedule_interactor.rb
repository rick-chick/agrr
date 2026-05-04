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
          unless input_dto.resource_type.present? && !input_dto.resource_id.nil?
            raise ArgumentError, "resource_type and resource_id are required"
          end

          event = @gateway.schedule(
            resource_type: input_dto.resource_type,
            resource_id: input_dto.resource_id,
            actor_id: input_dto.actor_id,
            toast_message: input_dto.toast_message,
            auto_hide_after: input_dto.auto_hide_after,
            metadata: input_dto.metadata,
            validate_before_schedule: input_dto.validate_before_schedule
          )

          @output_port.on_success(event)
        rescue DeletionUndo::Error => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto.new(
              reason: :undo_system_error,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto.new(
              reason: :validation_error,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Exceptions::AssociationInUse => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto.new(
              reason: :association_in_use,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied, ::PolicyPermissionDenied
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto.new(
              reason: :forbidden,
              detail_message: nil
            )
          )
        end
      end
    end
  end
end
