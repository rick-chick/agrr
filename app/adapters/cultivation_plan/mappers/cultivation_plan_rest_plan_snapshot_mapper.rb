# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # ActiveRecord → Domain::CultivationPlan::Dtos::CultivationPlanRestPlanSnapshot
      module CultivationPlanRestPlanSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        # @param plan [::CultivationPlan] CultivationPlanRestPlanPreload 相当の includes 済み
        # @return [Dtos::CultivationPlanRestPlanSnapshot]
        def from_cultivation_plan(plan)
          field_rows = plan.cultivation_plan_fields.map do |field|
            Dtos::CultivationPlanRestPlanFieldRowSnapshot.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost,
              display_name: field.display_name
            )
          end

          crop_rows = plan.cultivation_plan_crops.map do |crop|
            Dtos::CultivationPlanRestPlanCropRowSnapshot.new(
              id: crop.id,
              display_name: crop.display_name,
              area_per_unit: crop.area_per_unit,
              revenue_per_area: crop.revenue_per_area
            )
          end

          cultivation_rows = plan.field_cultivations.map do |fc|
            Dtos::CultivationPlanRestPlanCultivationRowSnapshot.new(
              id: fc.id,
              cultivation_plan_field_id: fc.cultivation_plan_field_id,
              field_display_name: fc.field_display_name,
              cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
              crop_display_name: fc.crop_display_name,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              estimated_cost: fc.estimated_cost,
              optimization_result: fc.optimization_result,
              status: fc.status
            )
          end

          palette_crop_ids = plan.cultivation_plan_crops.map { |cpc| cpc.crop&.id }.compact

          Dtos::CultivationPlanRestPlanSnapshot.new(
            id: plan.id,
            user_id: plan.user_id,
            plan_year: plan.plan_year,
            plan_name: plan.plan_name,
            display_name: plan.display_name,
            plan_type: plan.plan_type,
            status: plan.status,
            total_area: plan.total_area,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            calculated_planning_start_date: plan.calculated_planning_start_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            total_profit: plan.total_profit,
            total_revenue: plan.total_revenue,
            total_cost: plan.total_cost,
            farm_display_name: plan.farm.display_name,
            farm_region: plan.farm&.region,
            field_rows: field_rows,
            crop_rows: crop_rows,
            cultivation_rows: cultivation_rows,
            palette_crop_ids: palette_crop_ids
          )
        end
      end
    end
  end
end
