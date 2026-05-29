# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      CropDeleteUsageSnapshot = Data.define(
        :cultivation_plan_crops_count,
        :free_crop_plans_count,
        :pesticides_count
      )
    end
  end
end
