# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanRestPlanCultivationRowSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        # @param field_cultivation [::FieldCultivation]
        def from_field_cultivation(field_cultivation)
          Dtos::CultivationPlanRestPlanCultivationRowSnapshot.new(
            id: field_cultivation.id,
            cultivation_plan_field_id: field_cultivation.cultivation_plan_field_id,
            field_display_name: field_cultivation.field_display_name,
            cultivation_plan_crop_id: field_cultivation.cultivation_plan_crop_id,
            crop_display_name: field_cultivation.crop_display_name,
            area: field_cultivation.area,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days,
            estimated_cost: field_cultivation.estimated_cost,
            optimization_result: field_cultivation.optimization_result,
            status: field_cultivation.status
          )
        end
      end
    end
  end
end
