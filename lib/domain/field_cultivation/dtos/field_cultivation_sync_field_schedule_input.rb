# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationSyncFieldScheduleInput
        attr_reader :field_id, :allocations

        # @param field_id [Object]
        # @param allocations [Array<FieldCultivationSyncAllocationInput>]
        def initialize(field_id:, allocations:)
          @field_id = field_id
          @allocations = allocations.freeze
        end
      end
    end
  end
end
