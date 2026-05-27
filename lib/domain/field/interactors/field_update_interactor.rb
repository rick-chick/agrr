# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldUpdateInteractor < Domain::Field::Ports::FieldUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(update_input_dto)
          user = @user_lookup.find(@user_id)
          with_farm = @gateway.field_with_farm(update_input_dto.id)
          Domain::Field::Policies::FieldAccess.assert_owned!(user, farm: with_farm.farm)
          Domain::Field::Policies::FieldAccess.assert_field_edit_on_farm_allowed!(user, with_farm.farm)
          field = @gateway.update(update_input_dto.id, update_input_dto)
          @output_port.on_success(field)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end
      end
    end
  end
end
