# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class SunshineRequirementUpdateInteractor < Domain::Crop::Ports::SunshineRequirementUpdateInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          existing_requirement = @gateway.find_sunshine_requirement(input_dto.stage_id)

          if existing_requirement.nil?
            requirement = @gateway.create_sunshine_requirement(input_dto.stage_id, input_dto)
          else
            requirement = @gateway.update_sunshine_requirement(input_dto.stage_id, input_dto)
          end

          @output_port.on_success(Domain::Crop::Dtos::SunshineRequirementOutputDto.new(requirement: requirement))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end