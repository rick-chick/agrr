# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      # ActiveRecord → delete-usage wire（業務判断なし。関連件数のみ）。
      module FarmDeleteUsageWireMapper
        Wire = Data.define(:free_crop_plans_count)

        module_function

        # @param farm [Farm]
        # @return [Wire]
        def from_model(farm)
          Wire.new(free_crop_plans_count: farm.free_crop_plans.count)
        end
      end
    end
  end
end
