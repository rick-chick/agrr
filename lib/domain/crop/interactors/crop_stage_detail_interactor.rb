# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropStageDetailInteractor < Domain::Crop::Ports::CropStageDetailInputPort
        def initialize(output_port:, crop_stage_gateway:)
          @output_port = output_port
          @crop_stage_gateway = crop_stage_gateway
        end

        def call(input_dto)
          crop_stage = @crop_stage_gateway.find_by_id(input_dto.crop_stage_id)
          @output_port.on_success(Domain::Crop::Dtos::CropStageOutput.new(stage: crop_stage))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
