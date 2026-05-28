# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationSyncApplyMapperTest < DomainLibTestCase
        ApplyMapper = FieldCultivationSyncApplyMapper
        TargetMapper = FieldCultivationSyncTargetSnapshotMapper

        test "builds apply with field_cultivation diff and unreferenced plan_crop ids" do
          allocation = Dtos::FieldCultivationSyncAllocationInput.new(
            allocation_id: 9,
            crop_id: "3",
            start_date: Date.new(2026, 3, 1),
            completion_date: Date.new(2026, 3, 10)
          )
          field_schedule = Dtos::FieldCultivationSyncFieldScheduleInput.new(
            field_id: 2,
            allocations: [ allocation ]
          )
          sync_input = Dtos::FieldCultivationSyncInput.new(
            field_schedules: [ field_schedule ],
            total_profit: 1.0
          )
          plan_snapshot = Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: 1,
            plan_fields_by_id: { 2 => 20 },
            plan_crop_rows: [
              Dtos::FieldCultivationSyncPlanCropEntry.new(plan_crop_id: 30, crop_id: "3"),
              Dtos::FieldCultivationSyncPlanCropEntry.new(plan_crop_id: 90, crop_id: "9")
            ],
            existing_field_cultivations_by_id: {
              9 => Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3"
              ),
              99 => Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
                field_cultivation_id: 99,
                cultivation_plan_crop_id: 90,
                crop_id: "9"
              )
            }
          )
          target_snapshot = TargetMapper.to_target_snapshot(
            sync_input: sync_input,
            plan_snapshot: plan_snapshot
          )

          sync_apply = ApplyMapper.to_apply(
            plan_snapshot: plan_snapshot,
            target_snapshot: target_snapshot
          )

          assert_equal 1, sync_apply.field_cultivations_to_update.size
          assert_equal 0, sync_apply.field_cultivations_to_create.size
          assert_equal [ 99 ], sync_apply.field_cultivation_ids_to_delete
          assert_equal [ 90 ], sync_apply.cultivation_plan_crop_ids_to_delete
        end
      end
    end
  end
end
