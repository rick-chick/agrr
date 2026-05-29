# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationCropTaskTemplateRowSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleGenerationReadSnapshots::CropTaskTemplateRowSnapshot

        module_function

        # @param template [::CropTaskTemplate]
        # @return [Snapshot]
        def from_model(template)
          task = template.agricultural_task
          entity = task && Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
          Snapshot.new(agricultural_task: entity)
        end
      end
    end
  end
end
