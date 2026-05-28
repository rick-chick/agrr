# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module PlanAllocationAdjustReadSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot
        FieldCultivationSnapshot = Domain::CultivationPlan::Dtos::PlanAllocationAdjustFieldCultivationSnapshot
        Parts = Domain::CultivationPlan::Mappers::PlanAllocationAdjustReadSnapshotParts

        module_function

        # @param plan [CultivationPlan] preload 済み
        # @param crop_agrr_requirement_builder [#build_from]
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def from_cultivation_plan(plan, crop_agrr_requirement_builder:)
          plan_field_snapshots = plan.cultivation_plan_fields.map do |field|
            Snapshot::PlanFieldSnapshot.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          field_cultivation_snapshots = plan.field_cultivations.map do |fc|
            crop = fc.cultivation_plan_crop.crop
            FieldCultivationSnapshot.new(
              field_cultivation_id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              crop_id: crop.id,
              crop_name: fc.crop_display_name,
              variety: fc.cultivation_plan_crop.variety,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              stored_cultivation_days: fc.cultivation_days,
              crop_stage_count: crop.crop_stages.size,
              estimated_cost: fc.estimated_cost,
              optimization_result: fc.optimization_result
            )
          end

          plan_crop_snapshots = plan.cultivation_plan_crops.map do |plan_crop|
            crop = plan_crop.crop
            Parts.plan_crop_snapshot(
              crop_id: crop.id,
              crop_name: crop.name,
              groups: crop.groups,
              crop_stage_count: crop.crop_stages.size,
              build_agrr_requirement: -> { crop_agrr_requirement_builder.build_from(crop) }
            )
          end

          farm = plan.farm
          wl = farm&.weather_location
          weather_prediction_targets = Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
            weather_location: wl && Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(wl),
            farm: farm && Adapters::WeatherData::Mappers::FarmWeatherPredictionMapper.farm_weather_prediction_dto_from_record(farm)
          )

          field_source_snapshots = Parts.build_field_source_snapshots(
            plan_field_snapshots: plan_field_snapshots,
            field_cultivation_snapshots: field_cultivation_snapshots
          )

          cultivation_periods = field_cultivation_snapshots.map do |snapshot|
            Domain::CultivationPlan::Dtos::FieldCultivationPlanningPeriod.new(
              start_date: snapshot.start_date,
              completion_date: snapshot.completion_date
            )
          end

          Snapshot.new(
            plan_id: plan.id,
            field_source_snapshots: field_source_snapshots,
            plan_field_snapshots: plan_field_snapshots,
            plan_crop_snapshots: plan_crop_snapshots,
            cultivation_planning_periods: cultivation_periods,
            planning_period_boundaries: Domain::CultivationPlan::Dtos::PlanAllocationAdjustPlanningBoundaries.new(
              planning_start_date: plan.planning_start_date,
              planning_end_date: plan.planning_end_date
            ),
            cultivation_plan_weather_dto: Domain::WeatherData::Dtos::CultivationPlanWeather.new(
              id: plan.id,
              prediction_target_end_date: plan.prediction_target_end_date,
              calculated_planning_end_date: plan.calculated_planning_end_date,
              predicted_weather_data: plan.predicted_weather_data
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
