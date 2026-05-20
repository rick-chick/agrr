# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropStageDeleteInteractor < Domain::Crop::Ports::CropStageDeleteInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          @gateway.delete_crop_stage(input_dto.stage_id)
          @output_port.on_success(Domain::Crop::Dtos::CropStageDeleteOutput.new(success: true))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
