# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersTemperatureRequirementUpdateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          if @gateway.find_temperature_requirement(input_dto.stage_id).nil?
            @output_port.on_not_found
            return
          end

          requirement = @gateway.update_temperature_requirement(input_dto.stage_id, input_dto)
          @output_port.on_update_success(requirement)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_validation_errors(e.flatten_error_messages)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        end
      end
    end
  end
end
