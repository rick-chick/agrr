# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      # AR → domain read snapshot（plan_allocation_adjust）。
      module PlanAllocationAdjustReadPlanRowsSnapshotMapper
        Rows = Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadPlanRowsSnapshot

        module_function

        # @param plan [::CultivationPlan] ADJUST_INCLUDES preload 済み
        # @return [Rows::Plan]
        def from_cultivation_plan(plan)
          plan_fields = plan.cultivation_plan_fields.map do |field|
            Rows::PlanFieldRow.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          field_cultivations = plan.field_cultivations.map do |fc|
            crop = fc.cultivation_plan_crop.crop
            Rows::FieldCultivationRow.new(
              id: fc.id,
              cultivation_plan_field_id: fc.cultivation_plan_field_id,
              crop_id: crop.id,
              crop_name: fc.crop_display_name,
              variety: fc.cultivation_plan_crop.variety,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days,
              crop_stage_count: crop.crop_stages.size,
              estimated_cost: fc.estimated_cost,
              optimization_result: fc.optimization_result
            )
          end

          plan_crops = plan.cultivation_plan_crops.map do |plan_crop|
            crop = plan_crop.crop
            Rows::PlanCropRow.new(
              crop_id: crop.id,
              crop_name: crop.name,
              groups: crop.groups,
              crop_stage_count: crop.crop_stages.size
            )
          end

          Rows::Plan.new(
            id: plan.id,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            weather_prediction_targets:
              Adapters::WeatherData::Mappers::WeatherPredictionTargetsMapper.from_plan(plan),
            plan_fields: plan_fields,
            field_cultivations: field_cultivations,
            plan_crops: plan_crops
          )
        end
      end
    end
  end
end
