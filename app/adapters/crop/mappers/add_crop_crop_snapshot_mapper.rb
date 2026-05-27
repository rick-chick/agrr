# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      module AddCropCropSnapshotMapper
        module_function

        # @param source [#id, #name, #variety, #area_per_unit, #revenue_per_area]
        # @return [Domain::Crop::Dtos::AddCropCropSnapshot]
        def from_source(source)
          Domain::Crop::Dtos::AddCropCropSnapshot.new(
            id: source.id,
            name: source.name,
            variety: source.variety,
            area_per_unit: source.area_per_unit,
            revenue_per_area: source.revenue_per_area
          )
        end
      end
    end
  end
end
