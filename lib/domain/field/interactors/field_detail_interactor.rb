# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDetailInteractor < Domain::Field::Ports::FieldDetailInputPort
        def initialize(output_port:, user_id:, gateway:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(field_id)
          result = @gateway.field_with_farm_for_user(field_id, @user_id)
          @output_port.on_success(result)
        rescue Domain::Shared::Policies::PolicyPermissionDenied, PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        end
      end
    end
  end
end
