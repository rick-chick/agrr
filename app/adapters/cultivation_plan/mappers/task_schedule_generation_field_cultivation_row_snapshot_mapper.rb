# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationFieldCultivationRowSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleGenerationReadSnapshots::FieldCultivationRowSnapshot

        module_function

        # @param field_cultivation [::FieldCultivation]
        # @return [Snapshot]
        def from_model(field_cultivation)
          crop_id = field_cultivation.cultivation_plan_crop&.crop_id
          Snapshot.new(
            id: field_cultivation.id,
            start_date: field_cultivation.start_date,
            crop_id: crop_id
          )
        end
      end
    end
  end
end
