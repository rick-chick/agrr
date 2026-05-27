# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanWorkbenchReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanWorkbenchReadGateway
        def load_rows_by_plan_id_and_user_id(plan_id:, user_id:)
          cultivation_plan = Persistence::CultivationPlanRestPlanPreload.find_by_plan_id_and_user_id(
            plan_id: plan_id,
            user_id: user_id
          )
          rows_from_plan(cultivation_plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def load_rows_by_plan_id(plan_id:)
          cultivation_plan = Persistence::CultivationPlanRestPlanPreload.find_by_plan_id_public(
            plan_id: plan_id
          )
          rows_from_plan(cultivation_plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        private

        def rows_from_plan(cultivation_plan)
          plan_header = Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: cultivation_plan.id,
            user_id: cultivation_plan.user_id,
            plan_year: cultivation_plan.plan_year,
            plan_name: cultivation_plan.plan_name,
            plan_type: cultivation_plan.plan_type,
            status: cultivation_plan.status,
            total_area: cultivation_plan.total_area,
            planning_start_date: cultivation_plan.calculated_planning_start_date,
            planning_end_date: cultivation_plan.prediction_target_end_date,
            total_profit: cultivation_plan.total_profit,
            total_revenue: cultivation_plan.total_revenue,
            total_cost: cultivation_plan.total_cost
          )

          field_rows = cultivation_plan.cultivation_plan_fields.map do |field|
            Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchFieldRow.new(
              id: field.id,
              field_id: field.id,
              name: field.display_name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          crop_rows = cultivation_plan.cultivation_plan_crops.map do |crop|
            Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchCropRow.new(
              id: crop.id,
              name: crop.display_name,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            )
          end

          cultivation_rows = cultivation_plan.field_cultivations.map do |fc|
            Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchCultivationRow.new(
              id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              field_name: fc.field_display_name,
              crop_id: fc.cultivation_plan_crop_id,
              crop_name: fc.crop_display_name,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              estimated_cost: fc.estimated_cost,
              revenue: fc.optimization_result&.dig("revenue") || 0.0,
              profit: fc.optimization_result&.dig("profit") || 0.0,
              status: fc.status
            )
          end

          Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchRowsSnapshot.new(
            plan: plan_header,
            fields: field_rows,
            crops: crop_rows,
            cultivations: cultivation_rows,
            farm_region: cultivation_plan.farm&.region
          )
        end
      end
    end
  end
end
