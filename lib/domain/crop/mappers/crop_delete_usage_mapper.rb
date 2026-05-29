# frozen_string_literal: true

module Domain
  module Crop
    module Mappers
      module CropDeleteUsageMapper
        module_function

        # @param snapshot [Domain::Crop::Dtos::CropDeleteUsageSnapshot]
        # @return [Domain::Crop::Dtos::CropDeleteUsage]
        def from_snapshot(snapshot)
          Dtos::CropDeleteUsage.new(
            cultivation_plan_crops_count: snapshot.cultivation_plan_crops_count,
            free_crop_plans_count: snapshot.free_crop_plans_count,
            pesticides_count: snapshot.pesticides_count
          )
        end
      end
    end
  end
end
