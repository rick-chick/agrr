# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropStageListInteractor < Domain::Crop::Ports::CropStageListInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          crop_stages = @gateway.list_crop_stages_by_crop_id(input_dto.crop_id)
          @output_port.on_success(Domain::Crop::Dtos::CropStageListOutputDto.new(stages: crop_stages))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end