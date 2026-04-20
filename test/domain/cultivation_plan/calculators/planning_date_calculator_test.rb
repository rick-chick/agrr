# frozen_string_literal: true

require "test_helper"

class PlanningDateCalculatorTest < ActiveSupport::TestCase
  test "normalize_decimal returns string F format for numeric" do
    assert_equal "1.5", Domain::CultivationPlan::Calculators::PlanningDateCalculator.normalize_decimal(BigDecimal("1.5"))
  end

  test "normalize_decimal returns nil for nil" do
    assert_nil Domain::CultivationPlan::Calculators::PlanningDateCalculator.normalize_decimal(nil)
  end
end
