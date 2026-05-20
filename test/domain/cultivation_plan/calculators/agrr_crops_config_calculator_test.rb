# frozen_string_literal: true

require "domain_lib_test_helper"

class AgrrCropsConfigCalculatorTest < DomainLibTestCase
  test "build skips crops without stages and sets crop_id" do
    logger = Minitest::Mock.new
    logger.expect(:warn, nil, [ "⚠️ [AGRR] Skipping crop 'NoStage' (id=99): no growth stages" ])

    entries = [
      {
        crop_id: "10",
        crop_name: "Tomato",
        has_growth_stages: true,
        requirement: { "crop" => { "name" => "Tomato" } }
      },
      {
        crop_id: "99",
        crop_name: "NoStage",
        has_growth_stages: false,
        requirement: nil
      }
    ]

    result = Domain::CultivationPlan::Calculators::AgrrCropsConfigCalculator.build(entries: entries, logger: logger)

    assert_equal 1, result.size
    assert_equal "10", result.first.fetch("crop").fetch("crop_id")
    assert_equal "Tomato", result.first.fetch("crop").fetch("name")
    logger.verify
  end
end
