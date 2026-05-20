# frozen_string_literal: true

require "domain_lib_test_helper"

class AgrrCurrentAllocationCalculatorTest < DomainLibTestCase
  test "build aggregates optimization_result from field rows" do
    field_rows = [
      {
        field_id: 1,
        field_name: "North",
        field_area: 100.0,
        allocations: [
          {
            allocation_id: 10,
            crop_id: "5",
            crop_name: "Tomato",
            variety: "A",
            area_used: 40.0,
            start_date: Date.new(2025, 4, 1),
            completion_date: Date.new(2025, 7, 1),
            growth_days: 92,
            accumulated_gdd: 1.5,
            total_cost: 100.0,
            expected_revenue: 300.0
          }
        ]
      },
      {
        field_id: 2,
        field_name: "South",
        field_area: 50.0,
        allocations: []
      }
    ]

    result = Domain::CultivationPlan::Calculators::AgrrCurrentAllocationCalculator.build(
      cultivation_plan_id: 42,
      field_rows: field_rows
    )

    assert_equal "opt_42", result[:optimization_result][:optimization_id]
    assert_in_delta 100.0, result[:optimization_result][:total_cost]
    assert_in_delta 300.0, result[:optimization_result][:total_revenue]
    assert_in_delta 200.0, result[:optimization_result][:total_profit]

    schedules = result[:optimization_result][:field_schedules]
    assert_equal 2, schedules.size

    first = schedules.first
    assert_equal "1", first[:field_id]
    assert_equal "North", first[:field_name]
    assert_in_delta 0.4, first[:utilization_rate]
    alloc = first[:allocations].first
    assert_equal 10, alloc[:allocation_id]
    assert_equal "5", alloc[:crop_id]
    assert_equal "2025-04-01", alloc[:start_date]
    assert_equal "2025-07-01", alloc[:completion_date]
    assert_in_delta 200.0, alloc[:profit]

    assert_empty schedules.last[:allocations]
    assert_in_delta 0.0, schedules.last[:utilization_rate]
  end
end
