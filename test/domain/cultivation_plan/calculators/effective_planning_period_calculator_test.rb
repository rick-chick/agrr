# frozen_string_literal: true

require "domain_lib_test_helper"

class EffectivePlanningPeriodCalculatorTest < DomainLibTestCase
  test "calculate uses allocations and moves to extend range" do
    current_allocation = {
      optimization_result: {
        field_schedules: [
          {
            allocations: [
              {
                start_date: "2024-04-01",
                completion_date: "2024-06-01",
                allocation_id: 11
              }
            ]
          }
        ]
      }
    }
    moves = [ { to_start_date: "2025-02-10" } ]

    start_date, end_date = Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
      current_allocation: current_allocation,
      moves: moves,
      cultivation_periods: [],
      planning_start_date: Date.new(2023, 1, 1),
      planning_end_date: Date.new(2023, 12, 31),
      as_of: Date.new(2025, 5, 6)
    )

    assert_equal Date.new(2023, 1, 1), start_date
    assert_equal Date.new(2026, 12, 31), end_date
  end

  test "calculate uses planning dates or as_of when no periods exist" do
    start_date, end_date = Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
      current_allocation: {},
      moves: [],
      cultivation_periods: [],
      planning_start_date: Date.new(2024, 1, 15),
      planning_end_date: Date.new(2024, 12, 31),
      as_of: Date.new(2025, 5, 6)
    )

    assert_equal Date.new(2024, 1, 15), start_date
    assert_equal Date.new(2024, 12, 31), end_date

    start_date, end_date = Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
      current_allocation: {},
      moves: [],
      cultivation_periods: [],
      planning_start_date: nil,
      planning_end_date: nil,
      as_of: Date.new(2025, 5, 6)
    )

    assert_equal Date.new(2025, 5, 6), start_date
    assert_equal Date.new(2027, 12, 31), end_date
  end

  test "calculate raises error for invalid date" do
    error = assert_raises(Domain::CultivationPlan::Errors::EffectivePlanningPeriodInvalidDateError) do
      Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator.calculate(
        current_allocation: {
          optimization_result: {
            field_schedules: [
              {
                allocations: [
                  {
                    start_date: "invalid-date",
                    completion_date: nil,
                    allocation_id: 55
                  }
                ]
              }
            ]
          }
        },
        moves: [],
        cultivation_periods: [],
        planning_start_date: nil,
        planning_end_date: nil,
        as_of: Date.new(2025, 5, 6)
      )
    end

    assert_equal "invalid-date", error.raw_value
    assert_equal :start_date, error.field
    assert_equal 55, error.allocation_id
  end
end
