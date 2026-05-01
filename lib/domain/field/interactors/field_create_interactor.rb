# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldCreateInteractor < Domain::Field::Ports::FieldCreateInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @gateway.translator = translator if @gateway.respond_to?(:translator=)
        end

        def call(create_input_dto, farm_id)
          field = @gateway.create(create_input_dto, farm_id, @user_id)
          @output_port.on_success(field)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
