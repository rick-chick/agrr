# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class FieldCultivationSyncPolicyTest < DomainLibTestCase
        test "raises empty error when field_schedules is empty" do
          sync_input = Dtos::FieldCultivationSyncInput.new(field_schedules: [])

          assert_raises(Errors::FieldCultivationSyncEmptyError) do
            FieldCultivationSyncPolicy.validate!(sync_input)
          end
        end

        test "raises duplicate allocation error when allocation ids repeat" do
          allocation = Dtos::FieldCultivationSyncAllocationInput.new(
            allocation_id: 1,
            crop_id: "3",
            start_date: "2026-01-01",
            completion_date: "2026-01-10"
          )
          field_schedule = Dtos::FieldCultivationSyncFieldScheduleInput.new(
            field_id: 2,
            allocations: [ allocation, allocation ]
          )
          sync_input = Dtos::FieldCultivationSyncInput.new(field_schedules: [ field_schedule ])

          error = assert_raises(Errors::FieldCultivationSyncDuplicateAllocationError) do
            FieldCultivationSyncPolicy.validate!(sync_input)
          end
          assert_equal [ 1 ], error.duplicate_ids
        end
      end
    end
  end
end
