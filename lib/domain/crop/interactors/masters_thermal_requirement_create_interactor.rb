# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersThermalRequirementCreateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          unless @gateway.find_thermal_requirement(input_dto.stage_id).nil?
            @output_port.on_already_exists
            return
          end

          requirement = @gateway.create_thermal_requirement(input_dto.stage_id, input_dto)
          @output_port.on_create_success(requirement)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_validation_errors(e.flatten_error_messages)
        end
      end
    end
  end
end
