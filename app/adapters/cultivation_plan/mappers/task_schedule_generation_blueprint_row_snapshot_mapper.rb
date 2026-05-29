# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationBlueprintRowSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleGenerationReadSnapshots::BlueprintRowSnapshot

        module_function

        # @param blueprint [::CropTaskScheduleBlueprint]
        # @return [Snapshot]
        def from_model(blueprint)
          task = blueprint.agricultural_task
          entity = task && Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
          Snapshot.new(
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
