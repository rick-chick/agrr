# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressGateway
        # @param context [Domain::FieldCultivation::Dtos::FieldCultivationClimateContextSnapshot]
        # @param weather_payload [Hash]
        # @param use_mock [Boolean]
        # @return [Hash]
        def calculate_progress(context:, weather_payload:, use_mock:)
          raise NotImplementedError
        end
      end
    end
  end
end
