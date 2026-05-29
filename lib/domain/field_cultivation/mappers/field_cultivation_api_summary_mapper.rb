# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationApiSummaryMapper
        module_function

        # @param wire [#id, #field_name, #crop_name, #area, #start_date, #completion_date,
        #            #cultivation_days, #estimated_cost, #gdd, #status]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiSummary]
        def from_wire(wire)
          Dtos::FieldCultivationApiSummary.new(
            id: wire.id,
            field_name: wire.field_name,
            crop_name: wire.crop_name,
            area: wire.area,
            start_date: wire.start_date,
            completion_date: wire.completion_date,
            cultivation_days: wire.cultivation_days,
            estimated_cost: wire.estimated_cost,
            gdd: wire.gdd,
            status: wire.status
          )
        end
      end
    end
  end
end
