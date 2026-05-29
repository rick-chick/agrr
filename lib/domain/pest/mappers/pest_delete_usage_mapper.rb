# frozen_string_literal: true

module Domain
  module Pest
    module Mappers
      module PestDeleteUsageMapper
        module_function

        # @param snapshot [Domain::Pest::Dtos::PestDeleteUsageSnapshot]
        # @return [Domain::Pest::Dtos::PestDeleteUsage]
        def from_snapshot(snapshot)
          Dtos::PestDeleteUsage.new(pesticides_count: snapshot.pesticides_count)
        end
      end
    end
  end
end
