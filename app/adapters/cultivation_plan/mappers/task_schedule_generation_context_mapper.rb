# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationContextMapper
        module_function

        def from_plan_model(plan)
          field_rows = plan.field_cultivations.map do |fc|
            cpc = fc.cultivation_plan_crop
            crop = cpc&.crop
            next nil unless crop

            Domain::CultivationPlan::Dtos::FieldCultivationScheduleSnapshot.new(
              id: fc.id,
              start_date: fc.start_date,
              crop: crop_snapshot_from(crop)
            )
          end.compact

          snapshot = Domain::CultivationPlan::Dtos::TaskSchedulePlanSnapshot.new(
            id: plan.id,
            predicted_weather_data: plan.predicted_weather_data,
            calculated_planning_start_date: plan.calculated_planning_start_date,
            field_cultivations: field_rows
          )

          Domain::CultivationPlan::Dtos::TaskScheduleGenerationContext.new(plan: snapshot)
        end

        def crop_snapshot_from(crop)
          templates = crop.crop_task_templates.map do |t|
            at = t.agricultural_task
            entity = at ? Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(at) : nil
            Domain::CultivationPlan::Dtos::CropTaskTemplateSnapshot.new(agricultural_task: entity)
          end

          blueprints = crop.crop_task_schedule_blueprints
                             .includes(:agricultural_task)
                             .ordered
                             .map { |b| blueprint_snapshot_from(b) }

          Domain::CultivationPlan::Dtos::CropScheduleSnapshot.new(
            id: crop.id,
            name: crop.name,
            crop_task_templates: templates,
            crop_task_schedule_blueprints: blueprints,
            agrr_requirement: crop.to_agrr_requirement
          )
        end

        def blueprint_snapshot_from(blueprint)
          at = blueprint.agricultural_task
          entity = at ? Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(at) : nil
          Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintSnapshot.new(
            id: blueprint.id,
            task_type: blueprint.task_type,
            gdd_trigger: blueprint.gdd_trigger,
            gdd_tolerance: blueprint.gdd_tolerance,
            description: blueprint.description,
            stage_name: blueprint.stage_name,
            stage_order: blueprint.stage_order,
            priority: blueprint.priority,
            source: blueprint.source,
            weather_dependency: blueprint.weather_dependency,
            time_per_sqm: blueprint.time_per_sqm,
            amount: blueprint.amount,
            amount_unit: blueprint.amount_unit,
            agricultural_task: entity
          )
        end
      end
    end
  end
end
