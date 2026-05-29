# frozen_string_literal: true

module Domain
  module Farm
    module Mappers
      module FarmDeleteUsageMapper
        module_function

        # @param wire [#free_crop_plans_count]
        # @return [Domain::Farm::Dtos::FarmDeleteUsage]
        def from_wire(wire)
          Dtos::FarmDeleteUsage.new(free_crop_plans_count: wire.free_crop_plans_count)
        end
      end
    end
  end
end
