# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationSyncPlanCropResolverTest < DomainLibTestCase
        Resolver = FieldCultivationSyncPlanCropResolver
        Snapshot = Dtos::FieldCultivationSyncPlanSnapshot
        PlanCropEntry = Dtos::FieldCultivationSyncPlanCropEntry
        ExistingEntry = Dtos::FieldCultivationSyncExistingFieldCultivationEntry

        def build_snapshot(plan_crop_rows:, existing: {})
          Snapshot.new(
            plan_id: 1,
            plan_fields_by_id: { 2 => 20 },
            plan_crop_rows: plan_crop_rows,
            existing_field_cultivations_by_id: existing
          )
        end

        test "resolves plan_crop via existing field_cultivation when duplicate crop_id rows exist" do
          snapshot = build_snapshot(
            plan_crop_rows: [
              PlanCropEntry.new(plan_crop_id: 10, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 11, crop_id: "1")
            ],
            existing: {
              9 => ExistingEntry.new(
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 11,
                crop_id: "1"
              )
            }
          )
          allocation = Dtos::FieldCultivationSyncAllocationInput.new(
            allocation_id: 9,
            crop_id: "1",
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 10)
          )

          assert_equal 11, Resolver.resolve_plan_crop_id(plan_snapshot: snapshot, allocation: allocation)
        end

        test "resolves single plan_crop row by crop_id for new allocation" do
          snapshot = build_snapshot(
            plan_crop_rows: [ PlanCropEntry.new(plan_crop_id: 30, crop_id: "3") ]
          )
          allocation = Dtos::FieldCultivationSyncAllocationInput.new(
            crop_id: "3",
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 10)
          )

          assert_equal 30, Resolver.resolve_plan_crop_id(plan_snapshot: snapshot, allocation: allocation)
        end

        test "raises ambiguous when multiple plan_crop rows share crop_id without field_cultivation id" do
          snapshot = build_snapshot(
            plan_crop_rows: [
              PlanCropEntry.new(plan_crop_id: 10, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 11, crop_id: "1")
            ]
          )
          allocation = Dtos::FieldCultivationSyncAllocationInput.new(
            crop_id: "1",
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 10)
          )

          error = assert_raises(Errors::FieldCultivationSyncReferenceError) do
            Resolver.resolve_plan_crop_id(plan_snapshot: snapshot, allocation: allocation)
          end
          assert_equal Errors::FieldCultivationSyncReferenceError::KIND_PLAN_CROP_AMBIGUOUS, error.kind
        end
      end
    end
  end
end
