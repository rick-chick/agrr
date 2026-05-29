# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanRestPlanReadActiveRecordGatewayTest < ActiveSupport::TestCase
  HeaderSnapshot = Domain::CultivationPlan::Dtos::CultivationPlanRestPlanHeaderSnapshot
  FieldRowSnapshot = Domain::CultivationPlan::Dtos::CultivationPlanRestPlanFieldRowSnapshot

  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanRestPlanReadActiveRecordGateway.new
  end

  test "find_plan_header_snapshot_by_plan_id returns header snapshot" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

    header = @gateway.find_plan_header_snapshot_by_plan_id(plan_id: plan.id)

    assert_instance_of HeaderSnapshot, header
    assert_equal plan.id, header.id
    assert_equal user.id, header.user_id
  end

  test "list_rest_plan_field_row_snapshots_by_plan_id returns field rows" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")
    create(:cultivation_plan_field, cultivation_plan: plan, name: "K1", area: 10, daily_fixed_cost: 0)

    rows = @gateway.list_rest_plan_field_row_snapshots_by_plan_id(plan_id: plan.id)

    assert_equal 1, rows.size
    assert_instance_of FieldRowSnapshot, rows.first
    assert_equal "K1", rows.first.name
  end

  test "find_plan_header_snapshot_by_plan_id raises domain RecordNotFound when id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_plan_header_snapshot_by_plan_id(plan_id: 9_999_999)
    end
  end
end
