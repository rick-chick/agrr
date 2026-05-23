# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleInteractor < Domain::DeletionUndo::Ports::DeletionUndoScheduleInputPort
        def initialize(output_port:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call(input_dto)
          unless Domain::Shared.present?(input_dto.resource_type) && !input_dto.resource_id.nil?
            raise ArgumentError, "resource_type and resource_id are required"
          end

          ensure_schedule_authorized!(input_dto)

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
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoError => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure.new(
              reason: :undo_system_error,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure.new(
              reason: :validation_error,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Exceptions::AssociationInUse => e
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure.new(
              reason: :association_in_use,
              detail_message: e.message
            )
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(
            Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure.new(
              reason: :forbidden,
              detail_message: nil
            )
          )
        end

        private

        def ensure_schedule_authorized!(input_dto)
          user = begin
            @user_lookup.find(input_dto.actor_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          record = @gateway.find_schedulable_record!(input_dto.resource_type, input_dto.resource_id)
          allowed = Domain::DeletionUndo::ScheduleAuthorization.schedule_allowed?(user, record)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed
        end
      end
    end
  end
end
