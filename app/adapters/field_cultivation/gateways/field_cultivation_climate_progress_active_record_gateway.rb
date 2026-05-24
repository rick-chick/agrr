# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateProgressGateway
        def initialize(progress_gateway_factory:)
          @progress_gateway_factory = progress_gateway_factory
        end

        def calculate_progress(crop_entity:, start_date:, weather_payload:)
          crop_model = ::Crop.includes(crop_stages: [ :temperature_requirement, :thermal_requirement ]).find(crop_entity.id)
          progress_gateway = @progress_gateway_factory.call
          builder = Adapters::Crop::Ports::CropAgrrRequirementBuilderAdapter.new
          progress_gateway.calculate_progress(
            crop_requirement: builder.build_from(crop_model),
            start_date: start_date,
            weather_data: weather_payload,
            crop: crop_model
          )
        end
      end
    end
  end
end
