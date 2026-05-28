# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationSyncInteractorTest < DomainLibTestCase
        FakeLogger = Struct.new(:entries) do
          def initialize = super([])
          def info(msg, _progname = nil) = entries << [ :info, msg ]
        end

        class RecordingSyncGateway < Gateways::FieldCultivationSyncGateway
          attr_reader :applied_syncs, :loaded_plan_ids

          def initialize(plan_snapshot:)
            @plan_snapshot = plan_snapshot
            @applied_syncs = []
            @loaded_plan_ids = []
          end

          def find_sync_plan_snapshot_by_plan_id(plan_id:)
            @loaded_plan_ids << plan_id
            @plan_snapshot
          end

          def sync_by_plan_id(plan_id:, sync_apply:)
            @applied_syncs << [ plan_id, sync_apply ]
          end
        end

        test "validates then loads plan snapshot and applies sync" do
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
            plan_crops_by_crop_id: { "3" => 30 },
            existing_field_cultivation_ids: [ 9, 99 ]
          )
          gateway = RecordingSyncGateway.new(plan_snapshot: plan_snapshot)
          interactor = FieldCultivationSyncInteractor.new(sync_gateway: gateway, logger: FakeLogger.new)

          interactor.call(plan_id: 1, sync_input: sync_input)

          assert_equal [ 1 ], gateway.loaded_plan_ids
          assert_equal 1, gateway.applied_syncs.size
          _plan_id, sync_apply = gateway.applied_syncs.first
          assert_equal 1, sync_apply.field_cultivations_to_update.size
          assert_equal 0, sync_apply.field_cultivations_to_create.size
          assert_equal [ 99 ], sync_apply.field_cultivation_ids_to_delete
          assert_equal [ "3" ], sync_apply.referenced_crop_ids
        end

        test "does not sync when field_schedules is empty" do
          sync_input = Dtos::FieldCultivationSyncInput.new(field_schedules: [])
          gateway = RecordingSyncGateway.new(
            plan_snapshot: Dtos::FieldCultivationSyncPlanSnapshot.new(
              plan_id: 1,
              plan_fields_by_id: {},
              plan_crops_by_crop_id: {},
              existing_field_cultivation_ids: []
            )
          )
          interactor = FieldCultivationSyncInteractor.new(sync_gateway: gateway, logger: FakeLogger.new)

          assert_raises(Errors::FieldCultivationSyncEmptyError) do
            interactor.call(plan_id: 1, sync_input: sync_input)
          end
          assert_empty gateway.applied_syncs
        end

        test "does not sync when duplicate allocation ids detected" do
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
          gateway = RecordingSyncGateway.new(
            plan_snapshot: Dtos::FieldCultivationSyncPlanSnapshot.new(
              plan_id: 1,
              plan_fields_by_id: {},
              plan_crops_by_crop_id: {},
              existing_field_cultivation_ids: []
            )
          )
          interactor = FieldCultivationSyncInteractor.new(sync_gateway: gateway, logger: FakeLogger.new)

          assert_raises(Errors::FieldCultivationSyncDuplicateAllocationError) do
            interactor.call(plan_id: 1, sync_input: sync_input)
          end
          assert_empty gateway.applied_syncs
        end
      end
    end
  end
end
