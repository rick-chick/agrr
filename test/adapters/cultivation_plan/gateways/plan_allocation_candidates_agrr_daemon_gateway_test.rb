# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::PlanAllocationCandidatesAgrrDaemonGatewayTest < ActiveSupport::TestCase
  def gateway_with_inner(inner)
    gw = Adapters::CultivationPlan::Gateways::PlanAllocationCandidatesAgrrDaemonGateway.new
    gw.instance_variable_set(:@inner, inner)
    gw
  end

  def invoke_candidates(gateway)
    gateway.candidates(
      current_allocation: {},
      fields: [],
      crops: [],
      target_crop: "1",
      weather_data: {},
      planning_start: Date.new(2026, 1, 1),
      planning_end: Date.new(2026, 12, 31)
    )
  end

  test "maps NoAllocationCandidatesError to AllocationNoCandidatesError" do
    inner = mock
    inner.expects(:candidates).raises(
      Adapters::Agrr::Gateways::BaseGatewayV2::NoAllocationCandidatesError,
      "no valid allocation candidates"
    )

    error = assert_raises(Domain::CultivationPlan::Errors::AllocationNoCandidatesError) do
      invoke_candidates(gateway_with_inner(inner))
    end

    assert_equal "no valid allocation candidates", error.message
  end

  test "maps ExecutionError to AllocationExecutionError" do
    inner = mock
    inner.expects(:candidates).raises(
      Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
      "candidates command failed"
    )

    error = assert_raises(Domain::CultivationPlan::Errors::AllocationExecutionError) do
      invoke_candidates(gateway_with_inner(inner))
    end

    assert_equal "candidates command failed", error.message
  end

  test "maps ParseError to AllocationExecutionError" do
    inner = mock
    inner.expects(:candidates).raises(
      Adapters::Agrr::Gateways::BaseGatewayV2::ParseError,
      "invalid json"
    )

    error = assert_raises(Domain::CultivationPlan::Errors::AllocationExecutionError) do
      invoke_candidates(gateway_with_inner(inner))
    end

    assert_equal "invalid json", error.message
  end
end
