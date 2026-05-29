# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      module FarmDeleteUsageSnapshotMapper
        module_function

        # @param farm [Farm]
        # @return [Domain::Farm::Dtos::FarmDeleteUsageSnapshot]
        def from_model(farm)
          Domain::Farm::Dtos::FarmDeleteUsageSnapshot.new(
            free_crop_plans_count: farm.free_crop_plans.count
          )
        end
      end
    end
  end
end
