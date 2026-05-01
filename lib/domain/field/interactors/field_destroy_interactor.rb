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
          @gateway.translator = Domain::Shared::Ports::TranslatorPort.default if @gateway.respond_to?(:translator=)
        end

        def call(field_id)
          undo_response = @gateway.destroy(field_id, @user_id)
          dto = Domain::Field::Dtos::FieldDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(dto)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
