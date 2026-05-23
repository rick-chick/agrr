# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDetailInteractor < Domain::Field::Ports::FieldDetailInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(input)
          user = @user_lookup.find(@user_id)
          farm_access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          result = @gateway.field_with_farm_for_user(input.field_id, farm_access_filter: farm_access_filter)
          @output_port.on_success(result)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(failure_dto(e.message, input))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(failure_dto(e.message, input))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(failure_dto(e.message, input))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end

        private

        def failure_dto(message, input)
          Domain::Field::Dtos::FieldDetailFailure.new(message: message, farm_id: input.farm_id)
        end
      end
    end
  end
end
