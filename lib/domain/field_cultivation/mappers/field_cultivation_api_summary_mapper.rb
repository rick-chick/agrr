# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationApiSummaryMapper
        module_function

        # @param snapshot [Dtos::FieldCultivationApiSummarySnapshot]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationApiSummary]
        def from_snapshot(snapshot)
          Dtos::FieldCultivationApiSummary.new(
            id: snapshot.id,
            field_name: snapshot.field_name,
            crop_name: snapshot.crop_name,
            area: snapshot.area,
            start_date: snapshot.start_date,
            completion_date: snapshot.completion_date,
            cultivation_days: snapshot.cultivation_days,
            estimated_cost: snapshot.estimated_cost,
            gdd: snapshot.gdd,
            status: snapshot.status
          )
        end
      end
    end
  end
end
