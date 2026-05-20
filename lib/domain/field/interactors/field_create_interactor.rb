# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldCreateInteractor < Domain::Field::Ports::FieldCreateInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(create_input_dto, farm_id)
          user = @user_lookup.find(@user_id)
          farm_access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          field = @gateway.create(create_input_dto, farm_id, farm_access_filter: farm_access_filter)
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
