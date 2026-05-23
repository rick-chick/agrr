# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDestroyInteractor < Domain::Field::Ports::FieldDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(field_id)
          user = @user_lookup.find(@user_id)
          Domain::Field::Policies::FieldAccess.find_owned!(user, field_id)
          with_farm = @gateway.field_with_farm(field_id)
          Domain::Field::Policies::FieldAccess.assert_field_edit_on_farm_allowed!(user, with_farm.farm)
          undo_response = @gateway.delete(field_id)
          dto = Domain::Field::Dtos::FieldDestroyOutput.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::AssociationInUse
          @output_port.on_failure(
            Domain::Shared::Dtos::Error.new(@translator.t("fields.flash.cannot_delete_in_use"))
          )
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoError => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end
      end
    end
  end
end
