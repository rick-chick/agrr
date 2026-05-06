# frozen_string_literal: true

require "test_helper"

class AgrrInteractionRulesCalculatorTest < ActiveSupport::TestCase
  test "build generates unique rules with injected random" do
    crop_groups = {
      "1" => [ "leafy", "leafy" ],
      "2" => [ "root" ]
    }

    result = Domain::CultivationPlan::Calculators::AgrrInteractionRulesCalculator.build(
      crop_groups: crop_groups,
      random_hex: -> { "abcd1234" }
    )

    assert_equal 2, result.size
    rule_ids = result.map { |rule| rule[:rule_id] }
    assert_includes rule_ids, "continuous_leafy_abcd1234"
    assert_includes rule_ids, "continuous_root_abcd1234"
  end
end
