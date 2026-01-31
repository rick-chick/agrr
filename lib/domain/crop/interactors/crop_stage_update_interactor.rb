# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropStageUpdateInteractor < Domain::Crop::Ports::CropStageUpdateInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          crop_stage = @gateway.update_crop_stage(input_dto.stage_id, input_dto)
          @output_port.on_success(Domain::Crop::Dtos::CropStageOutputDto.new(stage: crop_stage))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end