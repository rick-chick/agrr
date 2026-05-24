# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class SaveAdjustedAgrrResultInteractorTest < DomainLibTestCase
        FakeLogger = Struct.new(:entries) do
          def initialize = super([])
          def info(msg, _progname = nil) = entries << [ :info, msg ]
        end

        class RecordingSaveGateway < Gateways::SaveAdjustedAgrrResultGateway
          attr_reader :applied_bundles, :loaded_plan_ids

          def initialize(context:)
            @context = context
            @applied_bundles = []
            @loaded_plan_ids = []
          end

          def load_persist_context(plan_id:)
            @loaded_plan_ids << plan_id
            @context
          end

          def apply_persist_bundle!(plan_id:, bundle:)
            @applied_bundles << [ plan_id, bundle ]
          end
        end

        test "validates then loads context and applies persist bundle" do
          allocation = Dtos::SaveAdjustedAgrrAllocationInput.new(
            allocation_id: 9,
            crop_id: "3",
            start_date: Date.new(2026, 3, 1),
            completion_date: Date.new(2026, 3, 10)
          )
          field_schedule = Dtos::SaveAdjustedAgrrFieldScheduleInput.new(
            field_id: 2,
            allocations: [ allocation ]
          )
          result = Dtos::SaveAdjustedAgrrResultInput.new(
            field_schedules: [ field_schedule ],
            total_profit: 1.0
          )
          context = Dtos::SaveAdjustedAgrrPersistContext.new(
            plan_id: 1,
            plan_fields_by_id: { 2 => 20 },
            plan_crops_by_crop_id: { "3" => 30 },
            existing_field_cultivation_ids: [ 9 ]
          )
          gateway = RecordingSaveGateway.new(context: context)
          interactor = SaveAdjustedAgrrResultInteractor.new(save_gateway: gateway, logger: FakeLogger.new)

          interactor.call(plan_id: 1, result: result)

          assert_equal [ 1 ], gateway.loaded_plan_ids
          assert_equal 1, gateway.applied_bundles.size
          _plan_id, bundle = gateway.applied_bundles.first
          assert_equal 1, bundle.upserts.size
          assert_equal 0, bundle.creates.size
          assert_equal [ "3" ], bundle.used_crop_ids
        end

        test "does not apply when duplicate allocation ids detected" do
          allocation = Dtos::SaveAdjustedAgrrAllocationInput.new(
            allocation_id: 1,
            crop_id: "3",
            start_date: "2026-01-01",
            completion_date: "2026-01-10"
          )
          field_schedule = Dtos::SaveAdjustedAgrrFieldScheduleInput.new(
            field_id: 2,
            allocations: [ allocation, allocation ]
          )
          result = Dtos::SaveAdjustedAgrrResultInput.new(field_schedules: [ field_schedule ])
          gateway = RecordingSaveGateway.new(
            context: Dtos::SaveAdjustedAgrrPersistContext.new(
              plan_id: 1,
              plan_fields_by_id: {},
              plan_crops_by_crop_id: {},
              existing_field_cultivation_ids: []
            )
          )
          interactor = SaveAdjustedAgrrResultInteractor.new(save_gateway: gateway, logger: FakeLogger.new)

          assert_raises(Errors::AdjustResultDuplicateAllocationError) do
            interactor.call(plan_id: 1, result: result)
          end
          assert_empty gateway.applied_bundles
        end
      end
    end
  end
end
