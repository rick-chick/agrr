# frozen_string_literal: true

module Domain
  module Pest
    module Mappers
      module PestDeleteUsageMapper
        module_function

        # @param wire [#pesticides_count]
        # @return [Domain::Pest::Dtos::PestDeleteUsage]
        def from_wire(wire)
          Dtos::PestDeleteUsage.new(pesticides_count: wire.pesticides_count)
        end
      end
    end
  end
end
