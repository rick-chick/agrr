# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanAddCropPlanCropInsertActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanAddCropPlanCropInsertGateway
        def initialize(logger:)
          super(logger: logger)
        end

        def create_plan_crop!(auth:, plan_id:, crop_entity:)
          cultivation_plan = ::Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader.find!(auth, plan_id)
          crop = ::Crop.find(crop_entity.id)

          plan_crop = cultivation_plan.cultivation_plan_crops.create!(
            crop: crop,
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area
          )

          {
            kind: :success,
            plan_crop_id: plan_crop.id,
            plan_crop_display_name: plan_crop.display_name
          }
        rescue ActiveRecord::RecordNotFound
          { kind: :not_found }
        rescue ActiveRecord::RecordInvalid => e
          logger.error "❌ [Add Crop insert] Record invalid: #{e.message}"
          { kind: :record_invalid, message: e.message }
        rescue ActiveRecord::ActiveRecordError => e
          logger.error "❌ [Add Crop insert] ActiveRecord error: #{e.message}"
          { kind: :unexpected, message: e.message }
        end
      end
    end
  end
end
