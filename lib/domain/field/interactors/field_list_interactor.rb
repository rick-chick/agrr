# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldListInteractor < Domain::Field::Ports::FieldListInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(farm_id)
          user = @user_lookup.find(@user_id)
          result = @gateway.farm_fields_list(farm_id)
          Domain::Field::Policies::FieldAccess.assert_field_edit_on_farm_allowed!(user, result.farm)
          Domain::Field::Policies::FieldAccess.assert_farm_fields_list_allowed!(user, result.farm)
          @output_port.on_success(result)
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
