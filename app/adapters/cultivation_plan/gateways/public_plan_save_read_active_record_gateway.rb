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
            farm_id: plan.farm_id,
            crop_ids: plan.crops.pluck(:id)
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
      end
    end
  end
end
