# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationCropRowSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleGenerationReadSnapshots::CropRowSnapshot

        module_function

        # @param crop [::Crop]
        # @return [Snapshot]
        def from_model(crop)
          Snapshot.new(id: crop.id, name: crop.name)
        end
      end
    end
  end
end
