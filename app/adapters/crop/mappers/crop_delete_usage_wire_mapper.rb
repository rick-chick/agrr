# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      # ActiveRecord → delete-usage wire（業務判断なし。関連件数のみ）。
      module CropDeleteUsageWireMapper
        Wire = Data.define(
          :cultivation_plan_crops_count,
          :free_crop_plans_count,
          :pesticides_count
        )

        module_function

        # @param crop [Crop]
        # @return [Wire]
        def from_model(crop)
          Wire.new(
            cultivation_plan_crops_count: crop.cultivation_plan_crops.count,
            free_crop_plans_count: crop.free_crop_plans.count,
            pesticides_count: crop.pesticides.count
          )
        end
      end
    end
  end
end
