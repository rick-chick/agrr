# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropDeleteUsage
        attr_reader :cultivation_plan_crops_count, :free_crop_plans_count, :pesticides_count

        def initialize(cultivation_plan_crops_count:, free_crop_plans_count:, pesticides_count:)
          @cultivation_plan_crops_count = cultivation_plan_crops_count
          @free_crop_plans_count = free_crop_plans_count
          @pesticides_count = pesticides_count
        end
      end
    end
  end
end
