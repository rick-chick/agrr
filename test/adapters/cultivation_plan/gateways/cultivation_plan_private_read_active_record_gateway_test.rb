# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGateway.new
  end

  test "list_private_plan_index_plan_snapshots returns empty array when user has no plans" do
    user = create(:user)

    wires = @gateway.list_private_plan_index_plan_snapshots(user_id: user.id)

    assert_empty wires
  end

  test "index assembly via domain mapper returns rows with counts in farm-flatten order" do
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

    plan_wires = @gateway.list_private_plan_index_plan_snapshots(user_id: user.id)
    plan_ids = plan_wires.map(&:id)
    crops_count_hash = @gateway.count_cultivation_plan_crops_by_plan_ids(plan_ids: plan_ids)
    fields_count_hash = @gateway.count_cultivation_plan_fields_by_plan_ids(plan_ids: plan_ids)
    plan_row_wires = Domain::CultivationPlan::Mappers::PrivatePlanIndexRowsMapper.plan_row_snapshots_with_counts(
      plan_wires,
      crops_count_hash: crops_count_hash,
      fields_count_hash: fields_count_hash
    )
    rows = Domain::CultivationPlan::Mappers::PrivatePlanIndexRowsMapper.to_index_rows(plan_row_wires)

    assert_equal 2, rows.size
    assert_equal [ plan_b.id, plan_a.id ], rows.map(&:id)

    row_a = rows.find { |r| r.id == plan_a.id }
    assert_equal 1, row_a.crops_count
    assert_equal 1, row_a.fields_count
    assert_equal farm_a.display_name, row_a.farm_display_name
    assert row_a.completed?

    row_b = rows.find { |r| r.id == plan_b.id }
    assert_equal 0, row_b.crops_count
    assert_equal 0, row_b.fields_count
  end

  test "find_plan_read_snapshot_by_plan_id returns wire for AR preload" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

    wire = @gateway.find_plan_read_snapshot_by_plan_id(plan_id: plan.id)
    snapshot = Domain::CultivationPlan::Mappers::PrivatePlanReadSnapshotMapper.from_snapshot(wire)

    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanReadSnapshot, snapshot
    assert_equal plan.id, snapshot.id
  end

  test "find_plan_read_snapshot_by_plan_id returns wire for plan owned by another user without scoping" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private")

    wire = @gateway.find_plan_read_snapshot_by_plan_id(plan_id: plan.id)
    snapshot = Domain::CultivationPlan::Mappers::PrivatePlanReadSnapshotMapper.from_snapshot(wire)

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
