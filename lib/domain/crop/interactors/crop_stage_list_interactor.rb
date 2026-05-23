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
          crop_stages = @gateway.list_by_crop_id(input_dto.crop_id)
          @output_port.on_success(Domain::Crop::Dtos::CropStageListOutput.new(stages: crop_stages))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
