# frozen_string_literal: true

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoRestoreInteractor < Domain::DeletionUndo::Ports::DeletionUndoRestoreInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          undo_token = input_dto.undo_token

          event = @gateway.find_by_token(undo_token)

          if event.expired? || !event.scheduled?
            if event.expired?
              @gateway.expire_if_needed(event.id)
            else
              @gateway.mark_failed(event.id, 'Token expired')
            end
            raise Domain::DeletionUndo::Exceptions::DeletionUndoExpiredError, 'Undo token has expired'
          end

          @gateway.perform_restore(event.id)

          output_dto = Domain::DeletionUndo::Dtos::DeletionUndoRestoreOutputDto.new(
            status: 'restored',
            undo_token: event.undo_token
          )
          @output_port.on_success(output_dto)
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoNotFoundError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new('Not found'))
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoExpiredError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoRestoreConflictError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end