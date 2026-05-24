# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class AdjustResultSavePolicyTest < DomainLibTestCase
        test "raises AdjustResultEmptyError when field_schedules is empty" do
          result = Dtos::SaveAdjustedAgrrResultInput.new(field_schedules: [])

          assert_raises(Errors::AdjustResultEmptyError) do
            AdjustResultSavePolicy.validate!(result)
          end
        end

        test "raises AdjustResultDuplicateAllocationError when allocation ids repeat" do
          allocation = Dtos::SaveAdjustedAgrrAllocationInput.new(
            allocation_id: 1,
            crop_id: "10",
            start_date: "2026-01-01",
            completion_date: "2026-01-10"
          )
          field_schedule = Dtos::SaveAdjustedAgrrFieldScheduleInput.new(
            field_id: 5,
            allocations: [ allocation, allocation ]
          )
          result = Dtos::SaveAdjustedAgrrResultInput.new(field_schedules: [ field_schedule ])

          error = assert_raises(Errors::AdjustResultDuplicateAllocationError) do
            AdjustResultSavePolicy.validate!(result)
          end
          assert_equal [ 1 ], error.duplicate_ids
        end

        test "passes when allocation ids are unique" do
          allocations = [
            Dtos::SaveAdjustedAgrrAllocationInput.new(
              allocation_id: 1,
              crop_id: "10",
              start_date: "2026-01-01",
              completion_date: "2026-01-10"
            ),
            Dtos::SaveAdjustedAgrrAllocationInput.new(
              allocation_id: 2,
              crop_id: "11",
              start_date: "2026-02-01",
              completion_date: "2026-02-10"
            )
          ]
          field_schedule = Dtos::SaveAdjustedAgrrFieldScheduleInput.new(field_id: 5, allocations: allocations)
          result = Dtos::SaveAdjustedAgrrResultInput.new(field_schedules: [ field_schedule ])

          AdjustResultSavePolicy.validate!(result)
        end
      end
    end
  end
end
