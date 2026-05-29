# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateProgressGateway
        def initialize(progress_gateway_factory:)
          @progress_gateway_factory = progress_gateway_factory
        end

        def calculate_progress(crop_requirement:, start_date:, weather_payload:, crop: nil)
          @progress_gateway_factory.call.calculate_progress(
            crop_requirement: crop_requirement,
            start_date: start_date,
            weather_data: weather_payload,
            crop: crop
          )
        end
      end
    end
  end
end
