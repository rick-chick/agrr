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
          attr_reader :applied_syncs

          def initialize
            @applied_syncs = []
          end

          def sync_by_plan_id(plan_id:, sync_apply:)
            @applied_syncs << [ plan_id, sync_apply ]
          end
        end

        class RecordingSyncPlanReadGateway < Gateways::FieldCultivationSyncPlanReadGateway
          attr_reader :loaded_plan_ids

          def initialize(plan_snapshot:)
            @plan_snapshot = plan_snapshot
            @loaded_plan_ids = []
          end

          def list_sync_plan_field_ids_by_plan_id(plan_id:)
            @loaded_plan_ids << plan_id
            @plan_snapshot.plan_fields_by_id.keys
          end

          def list_sync_plan_crop_entries_by_plan_id(plan_id:)
            @loaded_plan_ids << plan_id
            @plan_snapshot.plan_crop_rows
          end

          def list_sync_existing_field_cultivation_entries_by_plan_id(plan_id:)
            @loaded_plan_ids << plan_id
            @plan_snapshot.existing_field_cultivations_by_id.values
          end
        end

        test "loads plan snapshot then applies sync via gateway" do
          sync_input = Dtos::FieldCultivationSyncInput.new(
            field_schedules: [
              Dtos::FieldCultivationSyncFieldScheduleInput.new(
                field_id: 2,
                allocations: [
                  Dtos::FieldCultivationSyncAllocationInput.new(
                    allocation_id: 9,
                    crop_id: "3",
                    start_date: Date.new(2026, 3, 1),
                    completion_date: Date.new(2026, 3, 10)
                  )
                ]
              )
            ]
          )
          plan_snapshot = Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: 1,
            plan_fields_by_id: { 2 => 20 },
            plan_crop_rows: [
              Dtos::FieldCultivationSyncPlanCropEntry.new(plan_crop_id: 30, crop_id: "3")
            ],
            existing_field_cultivations_by_id: {
              9 => Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3"
              )
            }
          )
          sync_gateway = RecordingSyncGateway.new
          read_gateway = RecordingSyncPlanReadGateway.new(plan_snapshot: plan_snapshot)
          interactor = FieldCultivationSyncInteractor.new(
            sync_gateway: sync_gateway,
            sync_plan_read_gateway: read_gateway,
            logger: FakeLogger.new
          )

          interactor.call(plan_id: 1, sync_input: sync_input)

          assert_equal [ 1, 1, 1 ], read_gateway.loaded_plan_ids
          assert_equal 1, sync_gateway.applied_syncs.size
          plan_id, sync_apply = sync_gateway.applied_syncs.first
          assert_equal 1, plan_id
          assert_instance_of Dtos::FieldCultivationSyncApply, sync_apply
        end

        test "does not call sync when policy validation fails" do
          sync_input = Dtos::FieldCultivationSyncInput.new(field_schedules: [])
          plan_snapshot = Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: 1,
            plan_fields_by_id: {},
            plan_crop_rows: [],
            existing_field_cultivations_by_id: {}
          )
          sync_gateway = RecordingSyncGateway.new
          read_gateway = RecordingSyncPlanReadGateway.new(plan_snapshot: plan_snapshot)
          interactor = FieldCultivationSyncInteractor.new(
            sync_gateway: sync_gateway,
            sync_plan_read_gateway: read_gateway,
            logger: FakeLogger.new
          )

          assert_raises(Errors::FieldCultivationSyncEmptyError) do
            interactor.call(plan_id: 1, sync_input: sync_input)
          end
          assert_empty read_gateway.loaded_plan_ids
          assert_empty sync_gateway.applied_syncs
        end
      end
    end
  end
end
