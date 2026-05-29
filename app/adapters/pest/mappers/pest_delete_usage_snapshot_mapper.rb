# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      module PestDeleteUsageSnapshotMapper
        module_function

        # @param pest [Pest]
        # @return [Domain::Pest::Dtos::PestDeleteUsageSnapshot]
        def from_model(pest)
          Domain::Pest::Dtos::PestDeleteUsageSnapshot.new(
            pesticides_count: pest.pesticides.count
          )
        end
      end
    end
  end
end
