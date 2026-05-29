# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationSyncPlanSnapshotMapperTest < DomainLibTestCase
        test "from_snapshots builds plan snapshot from narrow read parts" do
          snapshot = FieldCultivationSyncPlanSnapshotMapper.from_snapshots(
            plan_id: 1,
            plan_field_ids: [ 2, 20 ],
            plan_crop_rows: [
              Dtos::FieldCultivationSyncPlanCropEntry.new(plan_crop_id: 30, crop_id: "3")
            ],
            existing_field_cultivation_entries: [
              Dtos::FieldCultivationSyncExistingFieldCultivationEntry.new(
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3"
              )
            ]
          )

          assert_equal 1, snapshot.plan_id
          assert_equal({ 2 => 2, 20 => 20 }, snapshot.plan_fields_by_id)
          assert_equal 1, snapshot.plan_crop_rows.size
          assert_equal 9, snapshot.existing_field_cultivations_by_id[9].field_cultivation_id
        end
      end
    end
  end
end
