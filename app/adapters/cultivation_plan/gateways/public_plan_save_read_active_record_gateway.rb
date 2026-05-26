# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class PublicPlanSaveReadActiveRecordGateway < Domain::CultivationPlan::Gateways::PublicPlanSaveReadGateway
        def find_header(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return nil unless plan

          Domain::CultivationPlan::Dtos::PublicPlanSaveHeaderSnapshot.new(
            plan_id: plan.id,
            farm_id: plan.farm_id
          )
        end

        def list_field_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_fields.filter_map do |field|
            Domain::CultivationPlan::Dtos::PublicPlanSaveFieldDatum.from_row(
              name: field.name,
              area: field.area,
              coordinates: [ 35.0, 139.0 ]
            )
          end
        end

        def list_crop_reference_rows(plan_id:)
          plan = ::CultivationPlan.find_by(id: plan_id)
          return [] unless plan

          plan.cultivation_plan_crops.includes(:crop).order(:id).map do |cpc|
            crop = cpc.crop
            Domain::CultivationPlan::Dtos::PublicPlanSaveCropReferenceRow.new(
              cultivation_plan_crop_id: cpc.id,
              reference_crop_id: crop.id,
              name: crop.name,
              variety: crop.variety,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area,
              groups: crop.groups,
              region: crop.region
            )
          end
        end
      end
    end
  end
end
