# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      class AddCropCropResolvePublic < Domain::CultivationPlan::Ports::AddCropCropResolveInputPort
        def initialize(crop_gateway:, logger:)
          @crop_gateway = crop_gateway
          @logger = logger
        end

        def call(_auth:, crop_id:)
          collector = AddCropCropResolveCollector.new
          Domain::Crop::Interactors::CropFindPublicPlanAddCropRecordInteractor.new(
            output_port: collector,
            gateway: @crop_gateway,
            logger: @logger
          ).call(crop_id)
          collector.crop_entity
        end
      end
    end
  end
end
