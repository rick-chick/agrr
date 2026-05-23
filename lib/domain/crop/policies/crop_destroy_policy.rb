# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      module CropDestroyPolicy
        module_function

        # @param usage [Domain::Crop::Dtos::CropDeleteUsage]
        # @return [Symbol, nil] :cultivation_plan | :other when delete must be blocked
        def blocked_reason(usage)
          return :cultivation_plan if usage.cultivation_plan_crops_count.positive?
          return :other if usage.free_crop_plans_count.positive? || usage.pesticides_count.positive?

          nil
        end
      end
    end
  end
end
