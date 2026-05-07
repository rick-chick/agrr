# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersNutrientRequirementCreateInteractor
        def initialize(output_port:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call(input_dto)
          unless @gateway.find_nutrient_requirement(input_dto.stage_id).nil?
            @output_port.on_already_exists
            return
          end

          requirement = @gateway.create_nutrient_requirement(input_dto.stage_id, input_dto)
          @output_port.on_create_success(requirement)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_validation_errors(e.flatten_error_messages)
        end
      end
    end
  end
end
