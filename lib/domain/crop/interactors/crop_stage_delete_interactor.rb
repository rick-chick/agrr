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
          @output_port.on_success(Domain::Crop::Dtos::CropStageDeleteOutputDto.new(success: true))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end