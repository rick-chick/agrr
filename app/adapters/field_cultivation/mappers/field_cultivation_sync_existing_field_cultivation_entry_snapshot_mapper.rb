# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      module FieldCultivationSyncExistingFieldCultivationEntrySnapshotMapper
        Dtos = Domain::FieldCultivation::Dtos

        module_function

        # @param field_cultivation [::FieldCultivation] includes(cultivation_plan_crop: :crop)
        # @return [Dtos::FieldCultivationSyncExistingFieldCultivationEntry]
        def from_field_cultivation(field_cultivation)
          Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
            field_cultivation_id: field_cultivation.id,
            cultivation_plan_crop_id: field_cultivation.cultivation_plan_crop_id,
            crop_id: field_cultivation.cultivation_plan_crop.crop.id
          )
        end
      end
    end
  end
end
