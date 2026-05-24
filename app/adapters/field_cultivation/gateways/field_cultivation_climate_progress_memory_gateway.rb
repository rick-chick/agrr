# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressMemoryGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateProgressGateway
        include ::Adapters::FieldCultivation::MockProgressRecords

        def initialize(logger:)
          @logger = logger
        end

        def calculate_progress(crop_entity:, start_date:, weather_payload:)
          completion = start_date + 30.days
          @logger.info "🧪 [FieldCultivationClimateProgressMemoryGateway] Using mock progress for crop_id=#{crop_entity.id}"
          {
            "progress_records" => generate_mock_progress_records(start_date, completion, logger: @logger),
            "total_gdd" => 875.0
          }
        end
      end
    end
  end
end
