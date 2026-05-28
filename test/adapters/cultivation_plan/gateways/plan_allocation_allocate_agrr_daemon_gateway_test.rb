# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::PlanAllocationAllocateAgrrDaemonGatewayTest < ActiveSupport::TestCase
  def gateway_with_inner(inner)
    gw = Adapters::CultivationPlan::Gateways::PlanAllocationAllocateAgrrDaemonGateway.new
    gw.instance_variable_set(:@inner, inner)
    gw
  end

  def invoke_allocate(gateway)
    gateway.allocate(
      fields: [],
      crops: [],
      weather_data: {},
      planning_start: Date.new(2026, 1, 1),
      planning_end: Date.new(2026, 12, 31)
    )
  end

  test "maps NoAllocationCandidatesError to AllocationNoCandidatesError" do
    inner = mock
    inner.expects(:allocate).raises(
      Adapters::Agrr::Gateways::BaseGatewayV2::NoAllocationCandidatesError,
      "no valid allocation candidates"
    )

    assert_raises(Domain::CultivationPlan::Errors::AllocationNoCandidatesError) do
      invoke_allocate(gateway_with_inner(inner))
    end
  end

  test "maps ExecutionError to AllocationExecutionError" do
    inner = mock
    inner.expects(:allocate).raises(
      Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
      "allocate command failed"
    )

    error = assert_raises(Domain::CultivationPlan::Errors::AllocationExecutionError) do
      invoke_allocate(gateway_with_inner(inner))
    end

    assert_equal "allocate command failed", error.message
  end
end
