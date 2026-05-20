# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # agrr adjust 結果の field_schedules の 1 要素。
      class SaveAdjustedAgrrFieldScheduleInput
        attr_reader :field_id, :allocations

        # @param field_id [Object]
        # @param allocations [Array<SaveAdjustedAgrrAllocationInput>]
        def initialize(field_id:, allocations:)
          @field_id = field_id
          @allocations = allocations.freeze
        end

        # @param fs [Hash]
        # @return [SaveAdjustedAgrrFieldScheduleInput]
        def self.from_hash(fs)
          fs = fs.to_h if fs.respond_to?(:to_h)
          raw_allocs = SaveAdjustedAgrrHashPick.pick(fs, :allocations)
          raw_allocs = [] if raw_allocs.nil?
          new(
            field_id: SaveAdjustedAgrrHashPick.pick(fs, :field_id),
            allocations: raw_allocs.map { |a| SaveAdjustedAgrrAllocationInput.from_hash(a) }
          )
        end
      end
    end
  end
end
