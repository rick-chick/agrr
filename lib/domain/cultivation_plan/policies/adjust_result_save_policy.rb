# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      module AdjustResultSavePolicy
        module_function

        # @param result [Domain::CultivationPlan::Dtos::SaveAdjustedAgrrResultInput]
        # @raise [Domain::CultivationPlan::Errors::AdjustResultEmptyError]
        # @raise [Domain::CultivationPlan::Errors::AdjustResultDuplicateAllocationError]
        def validate!(result)
          raise Errors::AdjustResultEmptyError if result.field_schedules.empty?

          allocation_ids = []
          result.field_schedules.each do |field_schedule|
            field_schedule.allocations.each do |allocation|
              raw = allocation.resolved_allocation_raw
              allocation_ids << raw unless raw.nil?
            end
          end

          compact_ids = allocation_ids.compact
          return if compact_ids.size == compact_ids.uniq.size

          duplicates = compact_ids.select { |id| allocation_ids.count(id) > 1 }.uniq
          raise Errors::AdjustResultDuplicateAllocationError.new(duplicate_ids: duplicates)
        end
      end
    end
  end
end
