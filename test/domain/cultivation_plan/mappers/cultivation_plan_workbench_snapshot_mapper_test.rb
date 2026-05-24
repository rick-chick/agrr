# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class CultivationPlanWorkbenchSnapshotMapperTest < DomainLibTestCase
        test "to_snapshot merges rows and available crops" do
          plan = Dtos::CultivationPlanWorkbenchPlanHeader.new(
            id: 1,
            plan_year: 2026,
            plan_name: "p",
            plan_type: "public",
            status: "draft",
            total_area: 1.0,
            planning_start_date: nil,
            planning_end_date: nil,
            total_profit: 0.0,
            total_revenue: 0.0,
            total_cost: 0.0
          )
          rows = Dtos::CultivationPlanWorkbenchRowsSnapshot.new(
            plan: plan,
            fields: [],
            crops: [],
            cultivations: [],
            farm_region: "us"
          )
          available = [ { id: 9 } ]

          snapshot = CultivationPlanWorkbenchSnapshotMapper.to_snapshot(
            rows: rows,
            available_crop_rows: available
          )

          assert_equal plan, snapshot.plan
          assert_equal available, snapshot.available_crop_rows
        end
      end
    end
  end
end
