# frozen_string_literal: true

module Domain
  module Crop
    module Mappers
      module CropDeleteUsageMapper
        module_function

        # @param wire [#cultivation_plan_crops_count, #free_crop_plans_count, #pesticides_count]
        # @return [Domain::Crop::Dtos::CropDeleteUsage]
        def from_wire(wire)
          Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: wire.cultivation_plan_crops_count,
            free_crop_plans_count: wire.free_crop_plans_count,
            pesticides_count: wire.pesticides_count
          )
        end
      end
    end
  end
end
