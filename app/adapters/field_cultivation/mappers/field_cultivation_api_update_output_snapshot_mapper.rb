# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      module FieldCultivationApiUpdateOutputSnapshotMapper
        module_function

        # @param field_cultivation [FieldCultivation]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutputSnapshot]
        def from_model(field_cultivation)
          Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutputSnapshot.new(
            field_cultivation_id: field_cultivation.id,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days
          )
        end
      end
    end
  end
end
