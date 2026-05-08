# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersNutrientRequirementShowInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          requirement = @gateway.find_nutrient_requirement(input_dto.crop_stage_id)
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
