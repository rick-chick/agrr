# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationApiUpdateOutputMapper
        module_function

        # @param wire [#field_cultivation_id, #start_date, #completion_date, #cultivation_days]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput]
        def from_wire(wire)
          Dtos::FieldCultivationApiUpdateOutput.new(
            field_cultivation_id: wire.field_cultivation_id,
            start_date: wire.start_date,
            completion_date: wire.completion_date,
            cultivation_days: wire.cultivation_days
          )
        end
      end
    end
  end
end
