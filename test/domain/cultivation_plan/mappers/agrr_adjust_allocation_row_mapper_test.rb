# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class AgrrAdjustAllocationRowMapperTest < DomainLibTestCase
        AllocationSnapshot = Dtos::PlanAllocationAdjustFieldCultivationAllocationSnapshot
        FieldSourceSnapshot = Dtos::PlanAllocationAdjustFieldSourceSnapshot

        test "build_current_allocation excludes ids and cultivations without growth stages" do
          included = AllocationSnapshot.new(
            field_cultivation_id: 10,
            field_id: 1,
            crop_id: "5",
            crop_name: "Tomato",
            variety: nil,
            area: 12.0,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 20),
            cultivation_days: 20,
            estimated_cost: 100.0,
            revenue: 200.0,
            accumulated_gdd: 1.0,
            has_growth_stages: true
          )
          excluded_id = AllocationSnapshot.new(
            field_cultivation_id: 11,
            field_id: 1,
            crop_id: "6",
            crop_name: "Skip",
            variety: nil,
            area: 1.0,
            start_date: Date.new(2026, 5, 1),
            completion_date: Date.new(2026, 5, 2),
            cultivation_days: 2,
            estimated_cost: 1.0,
            revenue: 2.0,
            accumulated_gdd: 0.0,
            has_growth_stages: true
          )
          no_stages = AllocationSnapshot.new(
            field_cultivation_id: 12,
            field_id: 1,
            crop_id: "7",
            crop_name: "NoStages",
            variety: nil,
            area: 1.0,
            start_date: Date.new(2026, 6, 1),
            completion_date: Date.new(2026, 6, 2),
            cultivation_days: 2,
            estimated_cost: 1.0,
            revenue: 2.0,
            accumulated_gdd: 0.0,
            has_growth_stages: false
          )
          field_snapshot = FieldSourceSnapshot.new(
            field_id: 1,
            field_name: "North",
            field_area: 100.0,
            cultivations: [ included, excluded_id, no_stages ]
          )

          payload = AgrrAdjustAllocationRowMapper.build_current_allocation(
            cultivation_plan_id: 99,
            field_snapshots: [ field_snapshot ],
            exclude_ids: [ 11 ]
          )

          schedules = payload.dig(:optimization_result, :field_schedules)
          assert_equal 1, schedules.size
          allocations = schedules.first[:allocations]
          assert_equal 1, allocations.size
          assert_equal 10, allocations.first[:allocation_id]
          assert_in_delta 100.0, allocations.first[:profit], 0.001
        end
      end
    end
  end
end
