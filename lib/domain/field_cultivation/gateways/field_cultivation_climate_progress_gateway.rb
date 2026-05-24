# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressGateway
        # @param crop_entity [Domain::Crop::Entities::CropEntity]
        # @param start_date [Date]
        # @param weather_payload [Hash]
        # @return [Hash]
        def calculate_progress(crop_entity:, start_date:, weather_payload:)
          raise NotImplementedError
        end
      end
    end
  end
end
