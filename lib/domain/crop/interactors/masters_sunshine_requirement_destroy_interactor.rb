# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class MastersSunshineRequirementDestroyInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          @gateway.delete_sunshine_requirement(input_dto.crop_stage_id)
          @output_port.on_destroy_success
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_not_found
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_validation_errors(e.flatten_error_messages)
        end
      end
    end
  end
end
