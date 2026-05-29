# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      module CropDeleteUsageSnapshotMapper
        module_function

        # @param crop [Crop]
        # @return [Domain::Crop::Dtos::CropDeleteUsageSnapshot]
        def from_model(crop)
          Domain::Crop::Dtos::CropDeleteUsageSnapshot.new(
            cultivation_plan_crops_count: crop.cultivation_plan_crops.count,
            free_crop_plans_count: crop.free_crop_plans.count,
            pesticides_count: crop.pesticides.count
          )
        end
      end
    end
  end
end
