# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateProgressGateway
        include ::Adapters::FieldCultivation::MockProgressRecords

        def initialize(logger:, progress_gateway_factory:)
          @logger = logger
          @progress_gateway_factory = progress_gateway_factory
        end

        def calculate_progress(crop_entity:, start_date:, weather_payload:, use_mock:)
          return mock_progress_result(start_date) if use_mock

          crop_model = ::Crop.includes(crop_stages: [ :temperature_requirement, :thermal_requirement ]).find(crop_entity.id)
          progress_gateway = @progress_gateway_factory.call
          progress_gateway.calculate_progress(
            crop: crop_model,
            start_date: start_date,
            weather_data: weather_payload
          )
        end

        private

        def mock_progress_result(start_date)
          completion = start_date + 30.days
          @logger.info "🧪 [FieldCultivationClimateProgressActiveRecordGateway] Using mock progress"
          {
            "progress_records" => generate_mock_progress_records(start_date, completion, logger: @logger),
            "total_gdd" => 875.0
          }
        end
      end
    end
  end
end
