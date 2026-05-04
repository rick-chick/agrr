# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDestroyInteractor < Domain::Field::Ports::FieldDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
        end

        def call(field_id)
          undo_response = @gateway.destroy(field_id, @user_id)
          dto = Domain::Field::Dtos::FieldDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::AssociationInUse => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue DeletionUndo::Error => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end
      end
    end
  end
end
