# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class CultivationPlanWorkbenchSnapshotMapperTest < DomainLibTestCase
        test "from_rest_plan_snapshot uses calculated planning dates in plan header" do
          snapshot_in = Dtos::CultivationPlanRestPlanSnapshot.new(
            id: 3,
            user_id: 1,
            plan_year: nil,
            plan_name: "W",
            display_name: "W",
            plan_type: "private",
            status: "optimizing",
            total_area: 200.0,
            planning_start_date: Date.new(2026, 1, 1),
            planning_end_date: Date.new(2026, 12, 31),
            calculated_planning_start_date: Date.new(2026, 2, 1),
            prediction_target_end_date: Date.new(2026, 11, 30),
            total_profit: 1.0,
            total_revenue: 2.0,
            total_cost: 1.0,
            farm_display_name: "Farm",
            farm_region: "us",
            field_rows: [
              Dtos::CultivationPlanRestPlanFieldRowSnapshot.new(
                id: 1, name: "n", area: 10.0, daily_fixed_cost: 0.5, display_name: "Field"
              )
            ],
            crop_rows: [
              Dtos::CultivationPlanRestPlanCropRowSnapshot.new(
                id: 2, display_name: "C", area_per_unit: 1.0, revenue_per_area: 2.0
              )
            ],
            cultivation_rows: [
              Dtos::CultivationPlanRestPlanCultivationRowSnapshot.new(
                id: 9,
                cultivation_plan_field_id: 1,
                field_display_name: "Field",
                cultivation_plan_crop_id: 2,
                crop_display_name: "C",
                area: 10.0,
                start_date: Date.new(2026, 3, 1),
                completion_date: Date.new(2026, 4, 1),
                cultivation_days: 30,
                estimated_cost: 1.0,
                optimization_result: { "revenue" => 100.0, "profit" => 50.0 },
                status: "completed"
              )
            ],
            palette_crop_ids: []
          )

          snapshot = CultivationPlanWorkbenchSnapshotMapper.from_rest_plan_snapshot(snapshot_in)

          assert_equal Date.new(2026, 2, 1), snapshot.plan.planning_start_date
          assert_equal Date.new(2026, 11, 30), snapshot.plan.planning_end_date
          assert_equal 50.0, snapshot.cultivations.first.profit
          assert_equal "us", snapshot.farm_region
        end
      end
    end
  end
end
