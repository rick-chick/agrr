# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDestroyInteractor < Domain::Field::Ports::FieldDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(field_id)
          user = @user_lookup.find(@user_id)
          farm_access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          undo_response = @gateway.destroy(field_id, farm_access_filter: farm_access_filter)
          dto = Domain::Field::Dtos::FieldDestroyOutput.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::AssociationInUse => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoError => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end
      end
    end
  end
end
