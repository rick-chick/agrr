# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module PlanAllocationAdjustReadSnapshotMapper
        FieldCultivationRow = Struct.new(
          :field_cultivation_id,
          :field_id,
          :crop_id,
          :crop_name,
          :variety,
          :area,
          :start_date,
          :completion_date,
          :cultivation_days,
          :estimated_cost,
          :optimization_result,
          :has_growth_stages,
          keyword_init: true
        )

        module_function

        # @param plan [CultivationPlan] preload 済み
        # @param crop_agrr_requirement_builder [#build_from]
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def from_cultivation_plan(plan, crop_agrr_requirement_builder:)
          plan_fields = plan.cultivation_plan_fields.map do |field|
            Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot::PlanFieldEntry.new(
              id: field.id,
              name: field.name,
              area: field.area,
              daily_fixed_cost: field.daily_fixed_cost
            )
          end

          field_cultivation_rows = plan.field_cultivations.map do |fc|
            crop = fc.cultivation_plan_crop.crop
            FieldCultivationRow.new(
              field_cultivation_id: fc.id,
              field_id: fc.cultivation_plan_field_id,
              crop_id: crop.id,
              crop_name: fc.crop_display_name,
              variety: fc.cultivation_plan_crop.variety,
              area: fc.area,
              start_date: fc.start_date,
              completion_date: fc.completion_date,
              cultivation_days: fc.cultivation_days || ((fc.completion_date - fc.start_date).to_i + 1),
              estimated_cost: fc.estimated_cost || 0.0,
              optimization_result: fc.optimization_result,
              has_growth_stages: crop.crop_stages.exists?
            )
          end

          plan_crop_entries = plan.cultivation_plan_crops.map do |plan_crop|
            crop = plan_crop.crop
            has_growth_stages = crop.crop_stages.exists?
            requirement = has_growth_stages ? crop_agrr_requirement_builder.build_from(crop) : nil

            Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot::PlanCropEntry.new(
              crop_id: crop.id,
              crop_name: crop.name,
              groups: crop.groups,
              has_growth_stages: has_growth_stages,
              agrr_requirement: requirement
            )
          end

          farm = plan.farm
          wl = farm&.weather_location
          weather_prediction_targets = Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
            weather_location: wl && Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(wl),
            farm: farm && Adapters::WeatherData::Mappers::FarmWeatherPredictionMapper.farm_weather_prediction_dto_from_record(farm)
          )

          parts = Domain::CultivationPlan::Mappers::PlanAllocationAdjustReadSnapshotParts
          field_source_rows = parts.build_field_source_rows(
            plan_fields: plan_fields,
            field_cultivations: field_cultivation_rows
          )

          cultivation_periods = field_cultivation_rows.map do |row|
            Domain::CultivationPlan::Dtos::FieldCultivationPlanningPeriod.new(
              start_date: row.start_date,
              completion_date: row.completion_date
            )
          end

          Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot.new(
            plan_id: plan.id,
            field_source_rows: field_source_rows,
            plan_fields: plan_fields,
            plan_crop_entries: plan_crop_entries,
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
            weather_location_facts: parts.weather_location_facts(weather_prediction_targets.weather_location),
            farm_without_weather_location: weather_prediction_targets.weather_location.nil?
          )
        end
      end
    end
  end
end
