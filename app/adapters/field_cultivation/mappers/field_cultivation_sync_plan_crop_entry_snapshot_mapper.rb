# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      module FieldCultivationSyncPlanCropEntrySnapshotMapper
        Dtos = Domain::FieldCultivation::Dtos

        module_function

        # @param plan_crop [::CultivationPlanCrop] includes(:crop)
        # @return [Dtos::FieldCultivationSyncPlanCropEntry]
        def from_plan_crop(plan_crop)
          Dtos::FieldCultivationSyncPlanCropEntry.new(
            plan_crop_id: plan_crop.id,
            crop_id: plan_crop.crop.id
          )
        end
      end
    end
  end
end
