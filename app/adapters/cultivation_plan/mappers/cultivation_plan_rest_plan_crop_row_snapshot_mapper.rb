# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanRestPlanCropRowSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        def from_plan_crop(plan_crop)
          Dtos::CultivationPlanRestPlanCropRowSnapshot.new(
            id: plan_crop.id,
            display_name: plan_crop.display_name,
            area_per_unit: plan_crop.area_per_unit,
            revenue_per_area: plan_crop.revenue_per_area
          )
        end
      end
    end
  end
end
