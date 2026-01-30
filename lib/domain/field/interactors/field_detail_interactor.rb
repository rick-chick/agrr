# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldDetailInteractor < Domain::Field::Ports::FieldDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(field_id)
          field = @gateway.find_by_id_and_user(field_id, @user_id)
          dto = Domain::Field::Dtos::FieldDetailOutputDto.new(field: field)
          @output_port.on_success(dto)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
