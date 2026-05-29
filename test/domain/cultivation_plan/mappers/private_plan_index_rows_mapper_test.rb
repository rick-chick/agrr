# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PrivatePlanIndexRowsMapperTest < DomainLibTestCase
        def plan_index_snapshot(id:, farm_display_name: "Farm", status: "draft")
          Dtos::PlanIndexPlanSnapshot.new(
            id: id,
            farm_display_name: farm_display_name,
            total_area: 100.0,
            status: status,
            display_name: "Plan #{id}",
            created_at: Time.utc(2026, 1, 1)
          )
        end

        test "plan_row_snapshots_with_counts merges count hashes into PlanRowSnapshot" do
          plans = [
            plan_index_snapshot(id: 1),
            plan_index_snapshot(id: 2, status: "completed")
          ]

          rows = PrivatePlanIndexRowsMapper.plan_row_snapshots_with_counts(
            plans,
            crops_count_hash: { 1 => 3, 2 => 0 },
            fields_count_hash: { 1 => 2, 2 => 5 }
          )

          assert_equal 2, rows.size
          row1 = rows.find { |r| r.id == 1 }
          assert_equal 3, row1.crops_count
          assert_equal 2, row1.fields_count
          assert_equal "Farm", row1.farm_display_name

          row2 = rows.find { |r| r.id == 2 }
          assert_equal 0, row2.crops_count
          assert_equal 5, row2.fields_count
        end

        test "to_index_rows builds PrivatePlanIndexPlanRow with completed predicate" do
          plan_rows = [
            Dtos::PlanRowSnapshot.new(
              id: 9,
              farm_display_name: "North",
              total_area: 50.0,
              crops_count: 1,
              fields_count: 2,
              status: "completed",
              display_name: "Done",
              created_at: Time.utc(2026, 2, 1)
            )
          ]

          rows = PrivatePlanIndexRowsMapper.to_index_rows(plan_rows)

          assert_equal 1, rows.size
          assert rows.first.completed?
          assert_equal "North", rows.first.farm_display_name
        end
      end
    end
  end
end
