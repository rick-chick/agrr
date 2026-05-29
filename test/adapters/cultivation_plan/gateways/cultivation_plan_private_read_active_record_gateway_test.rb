# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGatewayTest < ActiveSupport::TestCase
  PlanIndexPlanSnapshot = Domain::CultivationPlan::Dtos::PlanIndexPlanSnapshot
  RestPlanSnapshot = Domain::CultivationPlan::Dtos::CultivationPlanRestPlanSnapshot

  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGateway.new
  end

  test "list_private_plan_index_plan_snapshots returns empty array when user has no plans" do
    user = create(:user)

    snapshots = @gateway.list_private_plan_index_plan_snapshots(user_id: user.id)

    assert_empty snapshots
  end

  test "list_private_plan_index_plan_snapshots returns snapshots in farm-flatten order with AR fields" do
    user = create(:user)
    farm_a = create(:farm, user: user, name: "Farm A")
    farm_b = create(:farm, user: user, name: "Farm B")

    plan_a = create(:cultivation_plan, user: user, farm: farm_a, plan_type: "private", status: "completed",
                    plan_year: nil, plan_name: "PA",
                    planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2026, 12, 31))
    plan_b = create(:cultivation_plan, user: user, farm: farm_b, plan_type: "private", status: "pending",
                    plan_year: nil, plan_name: "PB",
                    planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2026, 12, 31))

    crop = create(:crop, user: user, is_reference: false)
    create(:cultivation_plan_crop, cultivation_plan: plan_a, crop: crop)
    create(:cultivation_plan_field, cultivation_plan: plan_a, name: "K1", area: 10, daily_fixed_cost: 0)

    snapshots = @gateway.list_private_plan_index_plan_snapshots(user_id: user.id)
    plan_ids = snapshots.map(&:id)
    crops_count_hash = @gateway.count_cultivation_plan_crops_by_plan_ids(plan_ids: plan_ids)
    fields_count_hash = @gateway.count_cultivation_plan_fields_by_plan_ids(plan_ids: plan_ids)

    assert_equal 2, snapshots.size
    assert snapshots.all?(PlanIndexPlanSnapshot)
    assert_equal [ plan_b.id, plan_a.id ], plan_ids

    snap_a = snapshots.find { |s| s.id == plan_a.id }
    assert_equal farm_a.display_name, snap_a.farm_display_name
    assert_equal "completed", snap_a.status
    assert_equal 1, crops_count_hash[plan_a.id]
    assert_equal 1, fields_count_hash[plan_a.id]

    snap_b = snapshots.find { |s| s.id == plan_b.id }
    assert_equal farm_b.display_name, snap_b.farm_display_name
    assert_nil crops_count_hash[plan_b.id]
    assert_nil fields_count_hash[plan_b.id]
  end

  test "find_plan_read_snapshot_by_plan_id returns CultivationPlanRestPlanSnapshot" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

    snapshot = @gateway.find_plan_read_snapshot_by_plan_id(plan_id: plan.id)

    assert_instance_of RestPlanSnapshot, snapshot
    assert_equal plan.id, snapshot.id
    assert_equal user.id, snapshot.user_id
    assert_equal "private", snapshot.plan_type
  end

  test "find_plan_read_snapshot_by_plan_id returns snapshot for plan owned by another user without scoping" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private")

    snapshot = @gateway.find_plan_read_snapshot_by_plan_id(plan_id: plan.id)

    assert_equal plan.id, snapshot.id
    assert other.id != owner.id
  end

  test "find_plan_read_snapshot_by_plan_id raises domain RecordNotFound when id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_plan_read_snapshot_by_plan_id(plan_id: 9_999_999)
    end
  end

  test "find_optimization_plan_read_snapshot_by_plan_id round-trips persisted plan" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    snapshot = @gateway.find_optimization_plan_read_snapshot_by_plan_id(plan_id: plan.id)

    assert_instance_of Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot, snapshot
    assert_equal plan.id, snapshot.plan_id
  end
end
