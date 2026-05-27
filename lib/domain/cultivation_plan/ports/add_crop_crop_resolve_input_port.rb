# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class AddCropCropResolveInputPort
        # @param crop_id [String, Integer]
        # @return [Domain::Crop::Dtos::AddCropCropSnapshot, nil]
        def call(crop_id:)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
