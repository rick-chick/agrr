# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module PlanAllocationAdjustReadSnapshotMapper
        Snapshot = Dtos::PlanAllocationAdjustReadSnapshot
        FieldCultivationSnapshot = Dtos::PlanAllocationAdjustFieldCultivationSnapshot
        Parts = PlanAllocationAdjustReadSnapshotParts

        module_function

        # @param plan_rows_snapshot [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadPlanRowsSnapshot::Plan]
        # @param plan_crop_agrr_builders [Array<#call>] plan_rows_snapshot.plan_crops と同順
        def from_snapshots(plan_rows_snapshot:, plan_crop_agrr_builders:)
          plan_field_snapshots = plan_rows_snapshot.plan_fields.map do |field|
            Snapshot::PlanFieldSnapshot.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          field_cultivation_snapshots = plan_rows_snapshot.field_cultivations.map do |fc|
            FieldCultivationSnapshot.new(
              field_cultivation_id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              crop_id: fc.crop_id,
              crop_name: fc.crop_name,
              variety: fc.variety,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              stored_cultivation_days: fc.cultivation_days,
              crop_stage_count: fc.crop_stage_count,
              estimated_cost: fc.estimated_cost,
              optimization_result: fc.optimization_result
            )
          end

          plan_crop_snapshots = plan_rows_snapshot.plan_crops.zip(plan_crop_agrr_builders).map do |plan_crop, build_agrr|
            Parts.plan_crop_snapshot(
              crop_id: plan_crop.crop_id,
              crop_name: plan_crop.crop_name,
              groups: plan_crop.groups,
              crop_stage_count: plan_crop.crop_stage_count,
              build_agrr_requirement: build_agrr
            )
          end

          weather_prediction_targets = plan_rows_snapshot.weather_prediction_targets

          field_source_snapshots = Parts.build_field_source_snapshots(
            plan_field_snapshots: plan_field_snapshots,
            field_cultivation_snapshots: field_cultivation_snapshots
          )

          cultivation_periods = field_cultivation_snapshots.map do |snapshot|
            Dtos::FieldCultivationPlanningPeriod.new(
              start_date: snapshot.start_date,
              completion_date: snapshot.completion_date
            )
          end

          Snapshot.new(
            plan_id: plan_rows_snapshot.id,
            field_source_snapshots: field_source_snapshots,
            plan_field_snapshots: plan_field_snapshots,
            plan_crop_snapshots: plan_crop_snapshots,
            cultivation_planning_periods: cultivation_periods,
            planning_period_boundaries: Dtos::PlanAllocationAdjustPlanningBoundaries.new(
              planning_start_date: plan_rows_snapshot.planning_start_date,
              planning_end_date: plan_rows_snapshot.planning_end_date
            ),
            cultivation_plan_weather_dto: Domain::WeatherData::Dtos::CultivationPlanWeather.new(
              id: plan_rows_snapshot.id,
              prediction_target_end_date: plan_rows_snapshot.prediction_target_end_date,
              calculated_planning_end_date: plan_rows_snapshot.calculated_planning_end_date,
              predicted_weather_data: plan_rows_snapshot.predicted_weather_data
            ),
            weather_prediction_targets: weather_prediction_targets,
            weather_location_facts: Parts.weather_location_facts(weather_prediction_targets.weather_location),
            farm_without_weather_location: weather_prediction_targets.weather_location.nil?
          )
        end
      end
    end
  end
end
