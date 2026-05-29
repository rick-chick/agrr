# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PlanAllocationAdjustReadPlanRowsSnapshotMapper
        module_function

        def load_plan_rows(read_gateway:, plan_id:)
          from_snapshots(
            header: read_gateway.find_adjust_plan_header_snapshot_by_plan_id(plan_id: plan_id),
            plan_fields: read_gateway.list_adjust_plan_field_rows_by_plan_id(plan_id: plan_id),
            field_cultivations: read_gateway.list_adjust_field_cultivation_rows_by_plan_id(plan_id: plan_id),
            plan_crops: read_gateway.list_adjust_plan_crop_rows_by_plan_id(plan_id: plan_id)
          )
        end

        def from_snapshots(header:, plan_fields:, field_cultivations:, plan_crops:)
          Dtos::PlanAllocationAdjustReadPlanRowsSnapshot.new(
            id: header.id,
            planning_start_date: header.planning_start_date,
            planning_end_date: header.planning_end_date,
            prediction_target_end_date: header.prediction_target_end_date,
            calculated_planning_end_date: header.calculated_planning_end_date,
            predicted_weather_data: header.predicted_weather_data,
            weather_prediction_targets: header.weather_prediction_targets,
            plan_fields: plan_fields,
            field_cultivations: field_cultivations,
            plan_crops: plan_crops
          )
        end
      end
    end
  end
end
