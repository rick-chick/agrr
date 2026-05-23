# frozen_string_literal: true

require "domain_lib_test_helper"

class ReferenceFlagChangeDeniedFailureTest < DomainLibTestCase
  test "exposes message and resource_id" do
    dto = Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(
      message: "admin only",
      resource_id: 42
    )

    assert_equal "admin only", dto.message
    assert_equal 42, dto.resource_id
  end
end
