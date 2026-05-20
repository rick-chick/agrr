# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationUpdateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          dto = @gateway.update_field_cultivation_schedule(
            field_cultivation_id: input_dto.field_cultivation_id,
            start_date: input_dto.start_date,
            completion_date: input_dto.completion_date,
            public_plan: input_dto.public_plan?
          )
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(e)
        end
      end
    end
  end
end
