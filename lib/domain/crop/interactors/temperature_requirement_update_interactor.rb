# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class TemperatureRequirementUpdateInteractor < Domain::Crop::Ports::TemperatureRequirementUpdateInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          existing_requirement = @gateway.find_temperature_requirement(input_dto.stage_id)

          if existing_requirement.nil?
            requirement = @gateway.create_temperature_requirement(input_dto.stage_id, input_dto)
          else
            requirement = @gateway.update_temperature_requirement(input_dto.stage_id, input_dto)
          end

          @output_port.on_success(Domain::Crop::Dtos::TemperatureRequirementOutputDto.new(requirement: requirement))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end