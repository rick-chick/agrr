# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust: adapter が AR から組み立てる行スナップショット（domain mapper の入力）。
      module PlanAllocationAdjustReadPlanRowsSnapshot
        PlanFieldRow = Data.define(:id, :name, :area, :daily_fixed_cost)
        FieldCultivationRow = Data.define(
          :id,
          :cultivation_plan_field_id,
          :crop_id,
          :crop_name,
          :variety,
          :area,
          :start_date,
          :completion_date,
          :cultivation_days,
          :crop_stage_count,
          :estimated_cost,
          :optimization_result
        )
        PlanCropRow = Data.define(:crop_id, :crop_name, :groups, :crop_stage_count)
        Plan = Data.define(
          :id,
          :planning_start_date,
          :planning_end_date,
          :prediction_target_end_date,
          :calculated_planning_end_date,
          :predicted_weather_data,
          :weather_prediction_targets,
          :plan_fields,
          :field_cultivations,
          :plan_crops
        )
      end
    end
  end
end
