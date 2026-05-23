# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::PlanAdjustActiveRecordGatewayTest < ActiveSupport::TestCase
  test "maps BaseGatewayV2 ExecutionError to AdjustExecutionError" do
    inner = mock
    inner.expects(:adjust).raises(
      ::Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
      "adjust command failed"
    )

    gateway = ::Adapters::CultivationPlan::Gateways::PlanAdjustActiveRecordGateway.new
    gateway.instance_variable_set(:@inner, inner)

    error = assert_raises(Domain::CultivationPlan::Errors::AdjustExecutionError) do
      gateway.adjust(
        current_allocation: {},
        moves: [],
        fields: [],
        crops: [],
        weather_data: {},
        planning_start: Date.new(2026, 1, 1),
        planning_end: Date.new(2026, 12, 31)
      )
    end

    assert_equal "adjust command failed", error.message
  end
end
