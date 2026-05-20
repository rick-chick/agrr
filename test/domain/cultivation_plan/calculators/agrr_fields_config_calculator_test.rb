# frozen_string_literal: true

require "domain_lib_test_helper"

class AgrrFieldsConfigCalculatorTest < DomainLibTestCase
  test "build maps fields and defaults daily_fixed_cost" do
    plan_fields = [
      {
        id: "10",
        name: "Field A",
        area: 1.25,
        daily_fixed_cost: nil
      }
    ]

    result = Domain::CultivationPlan::Calculators::AgrrFieldsConfigCalculator.build(plan_fields: plan_fields)

    assert_equal [
      {
        field_id: "10",
        name: "Field A",
        area: 1.25,
        daily_fixed_cost: 0.0
      }
    ], result
  end
end
