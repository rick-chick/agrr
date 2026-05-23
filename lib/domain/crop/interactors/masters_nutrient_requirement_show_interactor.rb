# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersNutrientRequirementShowInteractor
        def initialize(output_port:, gateway:, requirement_gateway:)
          @output_port = output_port
          @gateway = gateway
          @requirement_gateway = requirement_gateway
        end

        def call(input_dto)
          requirement = @requirement_gateway.find_by_crop_stage_id(input_dto.crop_stage_id)
          if requirement.nil?
            @output_port.on_not_found
          else
            @output_port.on_show_success(requirement)
          end
        end
      end
    end
  end
end
