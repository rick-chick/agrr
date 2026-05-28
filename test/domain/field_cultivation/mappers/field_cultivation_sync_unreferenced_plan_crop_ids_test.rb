# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationSyncUnreferencedPlanCropIdsTest < DomainLibTestCase
        Mapper = FieldCultivationSyncUnreferencedPlanCropIds
        Snapshot = Dtos::FieldCultivationSyncPlanSnapshot
        PlanCropEntry = Dtos::FieldCultivationSyncPlanCropEntry

        def build_snapshot(plan_crop_rows)
          Snapshot.new(
            plan_id: 1,
            plan_fields_by_id: {},
            plan_crop_rows: plan_crop_rows,
            existing_field_cultivations_by_id: {}
          )
        end

        test "returns empty when referenced_crop_ids is empty" do
          snapshot = build_snapshot(
            [
              PlanCropEntry.new(plan_crop_id: 10, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 20, crop_id: "2")
            ]
          )

          assert_empty Mapper.ids_to_delete(plan_snapshot: snapshot, referenced_crop_ids: [])
        end

        test "deletes plan crops whose crop_id is not referenced" do
          snapshot = build_snapshot(
            [
              PlanCropEntry.new(plan_crop_id: 10, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 20, crop_id: "2"),
              PlanCropEntry.new(plan_crop_id: 30, crop_id: "3")
            ]
          )

          ids = Mapper.ids_to_delete(plan_snapshot: snapshot, referenced_crop_ids: [ "1", 3 ])

          assert_equal [ 20 ], ids
        end

        test "retains all plan_crop rows sharing a referenced crop_id and deletes others" do
          snapshot = build_snapshot(
            [
              PlanCropEntry.new(plan_crop_id: 10, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 11, crop_id: "1"),
              PlanCropEntry.new(plan_crop_id: 20, crop_id: "2")
            ]
          )

          ids = Mapper.ids_to_delete(plan_snapshot: snapshot, referenced_crop_ids: [ "1" ])

          assert_equal [ 20 ], ids
        end
      end
    end
  end
end
