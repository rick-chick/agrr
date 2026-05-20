# frozen_string_literal: true

require "domain_lib_test_helper"

class FieldOptimizationEventPayloadTest < DomainLibTestCase
  test "to_h preserves cable shape" do
    dto = Domain::CultivationPlan::Dtos::FieldOptimizationEventSnapshot.new(
      id: 7,
      field_id: 7,
      name: "North",
      area: 120.5
    )
    assert_equal({ id: 7, field_id: 7, name: "North", area: 120.5 }, dto.to_h)
  end
end
