# frozen_string_literal: true

module Domain
  module Farm
    module Mappers
      module FarmDeleteUsageMapper
        module_function

        # @param snapshot [Domain::Farm::Dtos::FarmDeleteUsageSnapshot]
        # @return [Domain::Farm::Dtos::FarmDeleteUsage]
        def from_snapshot(snapshot)
          Dtos::FarmDeleteUsage.new(free_crop_plans_count: snapshot.free_crop_plans_count)
        end
      end
    end
  end
end
