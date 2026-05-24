# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanPlanCropActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanPlanCropGateway
        def create(auth:, plan_id:, crop_entity:)
          cultivation_plan = ::Adapters::CultivationPlan::Persistence::PlanScopes.find_record!(auth, plan_id)
          crop = ::Crop.find(crop_entity.id)

          plan_crop = cultivation_plan.cultivation_plan_crops.create!(
            crop: crop,
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area
          )

          Domain::CultivationPlan::Dtos::CultivationPlanCropSnapshot.new(
            id: plan_crop.id,
            display_name: plan_crop.display_name
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def delete(id:)
          record = ::CultivationPlanCrop.find_by(id: id)
          raise Domain::Shared::Exceptions::RecordNotFound, "Cultivation plan crop not found" unless record

          record.destroy!
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
