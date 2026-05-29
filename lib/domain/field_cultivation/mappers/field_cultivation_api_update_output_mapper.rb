# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationApiUpdateOutputMapper
        module_function

        # @param snapshot [Dtos::FieldCultivationApiUpdateOutputSnapshot]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput]
        def from_snapshot(snapshot)
          Dtos::FieldCultivationApiUpdateOutput.new(
            field_cultivation_id: snapshot.field_cultivation_id,
            start_date: snapshot.start_date,
            completion_date: snapshot.completion_date,
            cultivation_days: snapshot.cultivation_days
          )
        end
      end
    end
  end
end
