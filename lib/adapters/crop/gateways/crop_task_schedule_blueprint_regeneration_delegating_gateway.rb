# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropTaskScheduleBlueprintRegenerationDelegatingGateway < Domain::Crop::Gateways::CropTaskScheduleBlueprintRegenerationGateway
        def initialize(service: CropTaskScheduleBlueprintCreateService.new)
          @service = service
        end

        def regenerate_from_crop!(crop:)
          @service.regenerate!(crop: crop)
        rescue CropTaskScheduleBlueprintCreateService::MissingCropTaskTemplatesError => e
          raise Domain::Crop::Exceptions::MissingTaskTemplatesForBlueprintRegeneration, e.message
        rescue CropTaskScheduleBlueprintCreateService::GenerationFailedError => e
          raise Domain::Crop::Exceptions::BlueprintRegenerationFromAgrrFailed, e.message
        end

        private

        attr_reader :service
      end
    end
  end
end
