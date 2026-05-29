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

        def calculate_progress(crop_requirement:, start_date:, weather_payload:, crop: nil)
          completion = start_date + 30.days
          crop_label = crop&.id || crop_requirement.dig("crop", "id") || "unknown"
          @logger.info "🧪 [FieldCultivationClimateProgressMemoryGateway] Using mock progress for crop_id=#{crop_label}"
          {
            "progress_records" => generate_mock_progress_records(start_date, completion, logger: @logger),
            "total_gdd" => 875.0
          }
        end
      end
    end
  end
end
