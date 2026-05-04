# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldListInteractor < Domain::Field::Ports::FieldListInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @gateway.translator = translator if @gateway.respond_to?(:translator=)
        end

        def call(farm_id)
          result = @gateway.authorized_farm_fields_list(farm_id, @user_id)
          @output_port.on_success(result)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
