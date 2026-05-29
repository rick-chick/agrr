# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PrivatePlanReadSnapshotMapperTest < DomainLibTestCase
        test "from_snapshot maps profit via GanttChartRowHashes and plan metadata" do
          rest_plan_snapshot = Dtos::CultivationPlanRestPlanSnapshot.new(
            id: 1,
            user_id: 2,
            plan_year: 2026,
            plan_name: "Plan A",
            display_name: "Plan A (2026)",
            plan_type: "private",
            status: "completed",
            total_area: 100.0,
            planning_start_date: Date.new(2026, 1, 1),
            planning_end_date: Date.new(2026, 12, 31),
            calculated_planning_start_date: Date.new(2026, 1, 1),
            prediction_target_end_date: Date.new(2026, 12, 31),
            total_profit: 10.0,
            total_revenue: 20.0,
            total_cost: 10.0,
            farm_display_name: "Farm",
            farm_region: "jp",
            field_rows: [
              Dtos::CultivationPlanRestPlanFieldRowSnapshot.new(id: 10, name: "F1", area: 50.0, daily_fixed_cost: 1.0, display_name: "F1")
            ],
            crop_rows: [],
            cultivation_rows: [
              Dtos::CultivationPlanRestPlanCultivationRowSnapshot.new(
                id: 100,
                cultivation_plan_field_id: 10,
                field_display_name: "F1",
                cultivation_plan_crop_id: 20,
                crop_display_name: "Tomato",
                area: 50.0,
                start_date: Date.new(2026, 2, 1),
                completion_date: Date.new(2026, 5, 1),
                cultivation_days: 90,
                estimated_cost: 5.0,
                optimization_result: { "profit" => 42.5 },
                status: "completed"
              )
            ],
            palette_crop_ids: [ 7, 8 ]
          )

          snapshot = PrivatePlanReadSnapshotMapper.from_snapshot(rest_plan_snapshot)

          assert_equal 1, snapshot.id
          assert_equal "Plan A (2026)", snapshot.display_name
          assert_equal 1, snapshot.field_cultivations.size
          assert_equal 42.5, snapshot.field_cultivations.first.optimization_profit
          assert_equal [ 7, 8 ], snapshot.palette_used_crop_ids
        end
      end
    end
  end
end
