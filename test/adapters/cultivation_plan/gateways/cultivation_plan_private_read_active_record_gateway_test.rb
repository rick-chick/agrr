# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanPrivateReadActiveRecordGateway.new
  end

  test "list_private_plan_index_rows_by_user_id returns empty array when user has no plans" do
    user = create(:user)

    rows = @gateway.list_private_plan_index_rows_by_user_id(user_id: user.id)

    assert_empty rows
  end

  test "list_private_plan_index_rows_by_user_id returns rows with counts in farm-flatten order" do
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

    rows = @gateway.list_private_plan_index_rows_by_user_id(user_id: user.id)

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

  test "find_plan_read_rows_by_plan_id returns read rows without palette crops" do
    user = create(:user)
    farm = create(:farm, user: user, name: "My Farm")
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed",
                  planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2025, 12, 31))
    crop = create(:crop, user: user, is_reference: false, name: "Carrot", variety: "V1")
    create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)

    rows = @gateway.find_plan_read_rows_by_plan_id(plan_id: plan.id)

    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanReadRowsSnapshot, rows
    assert_equal plan.id, rows.id
    assert_equal plan.display_name, rows.display_name
    assert_equal farm.display_name, rows.farm_display_name
    assert_equal [ crop.id ], rows.palette_used_crop_ids
    assert_equal [], rows.field_cultivations
    assert_equal [], rows.cultivation_plan_fields
  end

  test "find_plan_read_rows_by_plan_id maps fields and field cultivations into read structs" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "pending")
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: "North", area: 50)
    crop = create(:crop, user: user, is_reference: false)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    fc = create(:field_cultivation,
                cultivation_plan: plan,
                cultivation_plan_field: field,
                cultivation_plan_crop: plan_crop,
                start_date: Date.new(2025, 3, 1),
                completion_date: Date.new(2025, 6, 1),
                optimization_result: { "profit" => 42 })

    rows = @gateway.find_plan_read_rows_by_plan_id(plan_id: plan.id)

    assert_equal 1, rows.field_cultivations_count
    assert_equal 1, rows.cultivation_plan_fields_count
    row = rows.field_cultivations.first
    assert_instance_of Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::FieldCultivationRead, row
    assert_equal fc.id, row.id
    assert_equal 42, row.optimization_profit

    fr = rows.cultivation_plan_fields.first
    assert_instance_of Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::PlanFieldRead, fr
    assert_equal "North", fr.name
  end

  test "find_plan_read_rows_by_plan_id returns rows for plan owned by another user without scoping" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private")

    rows = @gateway.find_plan_read_rows_by_plan_id(plan_id: plan.id)

    assert_equal plan.id, rows.id
    assert other.id != owner.id
  end

  test "find_plan_read_rows_by_plan_id raises domain RecordNotFound when id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_plan_read_rows_by_plan_id(plan_id: 9_999_999)
    end
  end

  test "find_optimization_read_by_plan_id returns read rows for mapper" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    rows = @gateway.find_optimization_read_by_plan_id(plan_id: plan.id)

    assert_instance_of Domain::CultivationPlan::Dtos::OptimizationPlanReadRows, rows
    assert_equal plan.id, rows.plan_id
    assert rows.plan_type_private?
  end
end
