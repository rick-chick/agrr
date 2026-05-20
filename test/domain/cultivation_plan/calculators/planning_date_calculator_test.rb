# frozen_string_literal: true

require "domain_lib_test_helper"

class PlanningDateCalculatorTest < DomainLibTestCase
  test "normalize_decimal returns string F format for numeric" do
    assert_equal "1.5", Domain::CultivationPlan::Calculators::PlanningDateCalculator.normalize_decimal(BigDecimal("1.5"))
  end

  test "calculate_plan_year_from_cultivations uses midpoint years from periods" do
    logger = Minitest::Mock.new
    logger.expect :debug, nil, [ String ]
    logger.expect :debug, nil, [ String ]
    logger.expect :debug, nil, [ String ]
    periods = [
      { start_date: Date.new(2024, 6, 1), completion_date: Date.new(2024, 8, 31) }
    ]
    year = Domain::CultivationPlan::Calculators::PlanningDateCalculator.calculate_plan_year_from_cultivations(
      cultivation_periods: periods,
      logger: logger,
      as_of: Date.new(2025, 1, 1)
    )
    assert_equal 2024, year
    logger.verify
  end

  test "calculate_planning_dates_from_cultivations returns default window when periods empty" do
    logger = Minitest::Mock.new
    logger.expect :info, nil, [ String ]
    as_of = Date.new(2025, 3, 15)
    dates = Domain::CultivationPlan::Calculators::PlanningDateCalculator.calculate_planning_dates_from_cultivations(
      cultivation_periods: [],
      logger: logger,
      as_of: as_of
    )
    assert_equal Date.new(as_of.year, 1, 1), dates[:start_date]
    assert_equal Date.new(2026, 12, 31), dates[:end_date]
    logger.verify
  end
end
