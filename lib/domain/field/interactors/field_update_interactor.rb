# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldUpdateInteractor < Domain::Field::Ports::FieldUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(update_input_dto)
          field = @gateway.update(update_input_dto.id, update_input_dto, @user_id)
          @output_port.on_success(field)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
