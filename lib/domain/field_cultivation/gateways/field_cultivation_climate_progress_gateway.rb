# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressGateway
        # @param crop_requirement [Hash] agrr crop requirement JSON（Interactor + builder で組立）
        # @param start_date [Date]
        # @param weather_payload [Hash]
        # @param crop [Object, nil] agrr デーモン用の AR crop（任意）
        # @return [Hash]
        def calculate_progress(crop_requirement:, start_date:, weather_payload:, crop: nil)
          raise NotImplementedError
        end
      end
    end
  end
end
