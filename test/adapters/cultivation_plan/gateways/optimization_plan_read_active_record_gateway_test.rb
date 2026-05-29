# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::OptimizationPlanReadActiveRecordGatewayTest < ActiveSupport::TestCase
  CoreSnapshot = Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot

  def setup
    @gateway = Adapters::CultivationPlan::Gateways::OptimizationPlanReadActiveRecordGateway.new
  end

  test "find_optimization_plan_core_snapshot_by_plan_id returns core snapshot" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    core = @gateway.find_optimization_plan_core_snapshot_by_plan_id(plan_id: plan.id)

    assert_instance_of CoreSnapshot, core
    assert_equal plan.id, core.plan_id
    assert core.plan_type_private
  end

  test "find_optimization_plan_core_snapshot_by_plan_id raises domain RecordNotFound when id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_optimization_plan_core_snapshot_by_plan_id(plan_id: 9_999_999)
    end
  end
end
