# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      module FieldCultivationApiSummarySnapshotMapper
        module_function

        # @param field_cultivation [FieldCultivation]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiSummary]
        def from_model(field_cultivation)
          Domain::FieldCultivation::Dtos::FieldCultivationApiSummary.new(
            id: field_cultivation.id,
            field_name: field_cultivation.field_display_name,
            crop_name: field_cultivation.crop_display_name,
            area: field_cultivation.area,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days,
            estimated_cost: field_cultivation.estimated_cost,
            gdd: field_cultivation.optimization_result&.dig("raw", "total_gdd"),
            status: field_cultivation.status
          )
        end
      end
    end
  end
end
