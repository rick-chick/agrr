# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      module FieldCultivationSyncPolicy
        module_function

        # @param sync_input [Domain::FieldCultivation::Dtos::FieldCultivationSyncInput]
        # @raise [Domain::FieldCultivation::Errors::FieldCultivationSyncEmptyError]
        # @raise [Domain::FieldCultivation::Errors::FieldCultivationSyncDuplicateAllocationError]
        def validate!(sync_input)
          raise Errors::FieldCultivationSyncEmptyError if sync_input.field_schedules.empty?

          allocation_ids = []
          sync_input.field_schedules.each do |field_schedule|
            field_schedule.allocations.each do |allocation|
              raw = allocation.resolved_allocation_raw
              allocation_ids << raw unless raw.nil?
            end
          end

          compact_ids = allocation_ids.compact
          return if compact_ids.size == compact_ids.uniq.size

          duplicates = compact_ids.select { |id| allocation_ids.count(id) > 1 }.uniq
          raise Errors::FieldCultivationSyncDuplicateAllocationError.new(duplicate_ids: duplicates)
        end
      end
    end
  end
end
