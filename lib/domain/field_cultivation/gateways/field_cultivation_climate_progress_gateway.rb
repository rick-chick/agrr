# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressGateway
        # @param crop_entity [Domain::Crop::Entities::CropEntity]
        # @param start_date [Date]
        # @param weather_payload [Hash]
        # @param use_mock [Boolean]
        # @return [Hash]
        def calculate_progress(crop_entity:, start_date:, weather_payload:, use_mock:)
          raise NotImplementedError
        end
      end
    end
  end
end
