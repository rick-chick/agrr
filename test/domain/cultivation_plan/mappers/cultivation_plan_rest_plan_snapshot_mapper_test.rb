# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class CultivationPlanRestPlanSnapshotMapperTest < DomainLibTestCase
        test "from_snapshots assembles composite snapshot" do
          header = Dtos::CultivationPlanRestPlanHeaderSnapshot.new(
            id: 1,
            user_id: 2,
            plan_year: 2026,
            plan_name: "n",
            display_name: "d",
            plan_type: "private",
            status: "draft",
            total_area: 10.0,
            planning_start_date: nil,
            planning_end_date: nil,
            calculated_planning_start_date: nil,
            prediction_target_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0,
            farm_display_name: "Farm",
            farm_region: "jp"
          )
          field_row = Dtos::CultivationPlanRestPlanFieldRowSnapshot.new(
            id: 3, name: "f", area: 1.0, daily_fixed_cost: 0.0, display_name: "F"
          )

          snapshot = CultivationPlanRestPlanSnapshotMapper.from_snapshots(
            header: header,
            field_rows: [ field_row ],
            crop_rows: [],
            cultivation_rows: [],
            palette_crop_ids: [ 9 ]
          )

          assert_equal 1, snapshot.id
          assert_equal [ field_row ], snapshot.field_rows
          assert_equal [ 9 ], snapshot.palette_crop_ids
        end
      end
    end
  end
end
