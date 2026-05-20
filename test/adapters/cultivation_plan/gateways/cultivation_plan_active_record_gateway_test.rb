# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new(
      deletion_undo_gateway: Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
    )
  end

  test "should find existing cultivation plan" do
    user = create(:user)
    farm = create(:farm, user: user)
    existing_plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    found_plan = @gateway.find_existing(farm, user)

    assert_not_nil found_plan
    assert_equal existing_plan.id, found_plan.id
    assert_instance_of Domain::CultivationPlan::Entities::CultivationPlanEntity, found_plan
  end

  test "should return nil when no existing plan found" do
    user = create(:user)
    farm = create(:farm, user: user)

    found_plan = @gateway.find_existing(farm, user)

    assert_nil found_plan
  end

  test "should find farm by id and user" do
    user = create(:user)
    farm = create(:farm, user: user)

    found_farm = @gateway.find_farm(farm.id, user)

    assert_not_nil found_farm
    assert_equal farm.id, found_farm.id
    assert_equal farm.name, found_farm.name
    assert_instance_of Domain::Farm::Entities::FarmEntity, found_farm
  end

  test "should return nil when farm not found" do
    user = create(:user)

    found_farm = @gateway.find_farm(9999, user)

    assert_nil found_farm
  end

  test "should find crops by ids and user" do
    user = create(:user)
    crop1 = create(:crop, user: user, is_reference: false)
    crop2 = create(:crop, user: user, is_reference: false)
    # 参照作物は除外されるべき（user_idなしで作成）
    create(:crop, :reference)

    found_crops = @gateway.find_crops([ crop1.id, crop2.id ], user)

    assert_equal 2, found_crops.length
    assert_instance_of Array, found_crops
    crop_ids = found_crops.map(&:id)
    assert_includes crop_ids, crop1.id
    assert_includes crop_ids, crop2.id
  end

  test "should return empty array when no crops found" do
    user = create(:user)

    found_crops = @gateway.find_crops([ 9999 ], user)

    assert_empty found_crops
  end

  test "private_plan_optimizing_snapshot returns read model for owned private plan" do
    user = create(:user)
    farm = create(:farm, user: user, name: "表示農場")
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "optimizing",
                  plan_year: 2024, optimization_phase_message: "phase1")
    crop = create(:crop, user: user, is_reference: false)
    create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    create(:cultivation_plan_crop, cultivation_plan: plan, crop: create(:crop, user: user, is_reference: false))

    read = @gateway.private_plan_optimizing_snapshot(plan_id: plan.id, user: user)
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanOptimizingAssembler.call(read)

    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanOptimizingSnapshot, read
    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanOptimizing, dto
    assert_equal plan.id, dto.id
    assert_equal 2024, dto.plan_year
    assert_equal farm.display_name, dto.farm_display_name
    assert_equal 2, dto.cultivation_plan_crops_count
    assert_equal "phase1", dto.optimization_phase_message
    assert_equal "optimizing", dto.status
    assert_not dto.completed?
  end

  test "private_plan_optimizing_snapshot raises domain RecordNotFound when plan belongs to another user" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private")

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.private_plan_optimizing_snapshot(plan_id: plan.id, user: other)
    end
  end

  test "private_plan_optimizing_snapshot raises domain RecordNotFound when id missing" do
    user = create(:user)

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.private_plan_optimizing_snapshot(plan_id: 9_999_999, user: user)
    end
  end

  test "public_plan_optimizing_snapshot returns read model for public plan" do
    farm = create(:farm, name: "公開テスト農場")
    plan = create(:cultivation_plan, :public_plan, farm: farm, status: "optimizing",
                  optimization_phase_message: "working")

    read = @gateway.public_plan_optimizing_snapshot(plan_id: plan.id)
    dto = Domain::CultivationPlan::Assemblers::PublicPlanOptimizingAssembler.call(read)

    assert_instance_of Domain::CultivationPlan::Dtos::PublicPlanOptimizingSnapshot, read
    assert_instance_of Domain::CultivationPlan::Dtos::PublicPlanOptimizing, dto
    assert_equal plan.id, dto.id
    assert_equal farm.display_name, dto.farm_display_name
    assert_equal 0, dto.cultivation_plan_crops_count
    assert_equal "working", dto.optimization_phase_message
    assert_equal "optimizing", dto.status
  end

  test "public_plan_optimizing_snapshot raises when plan is private" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.public_plan_optimizing_snapshot(plan_id: plan.id)
    end
  end

  test "public_plan_optimizing_snapshot raises domain RecordNotFound when id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.public_plan_optimizing_snapshot(plan_id: 9_999_999)
    end
  end

  test "private_plan_index_plan_rows returns empty array when user has no plans" do
    user = create(:user)

    rows = @gateway.private_plan_index_plan_rows(user: user)
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanIndexAssembler.call(plan_rows: rows)

    assert_empty rows
    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanIndex, dto
    assert_predicate dto, :empty?
    assert_empty dto.plan_rows
  end

  test "private_plan_index_plan_rows returns rows with counts in farm-flatten order" do
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

    rows = @gateway.private_plan_index_plan_rows(user: user)
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanIndexAssembler.call(plan_rows: rows)

    assert_equal 2, dto.plan_rows.size
    # recent: plan_b が新しいので先頭 → group_by で farm_b ブロックが先に登場し、その後 farm_a
    assert_equal [ plan_b.id, plan_a.id ], dto.plan_rows.map(&:id)

    row_a = dto.plan_rows.find { |r| r.id == plan_a.id }
    assert_equal 1, row_a.crops_count
    assert_equal 1, row_a.fields_count
    assert_equal farm_a.display_name, row_a.farm_display_name
    assert row_a.completed?

    row_b = dto.plan_rows.find { |r| r.id == plan_b.id }
    assert_equal 0, row_b.crops_count
    assert_equal 0, row_b.fields_count
  end

  test "find_private_cultivation_plan_detail returns detail dto for owned private plan with palette and counts" do
    user = create(:user)
    farm = create(:farm, user: user, name: "My Farm")
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed",
                  planning_start_date: Date.new(2025, 1, 1), planning_end_date: Date.new(2025, 12, 31))
    crop = create(:crop, user: user, is_reference: false, name: "Carrot", variety: "V1")
    create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)

    dto = @gateway.find_private_cultivation_plan_detail(user: user, plan_id: plan.id)

    assert_instance_of Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail, dto
    assert_equal plan.id, dto.id
    assert_equal plan.display_name, dto.display_name
    assert_equal farm.display_name, dto.farm_display_name
    assert_equal plan.total_area, dto.total_area
    assert_equal 0, dto.field_cultivations_count
    assert_equal 0, dto.cultivation_plan_fields_count
    assert_equal "completed", dto.status
    assert_equal [], dto.field_cultivations
    assert_equal [], dto.cultivation_plan_fields
    assert_equal [ crop.id ], dto.palette_used_crop_ids
    assert_equal 1, dto.palette_crops.size
    pc = dto.palette_crops.first
    assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanShowPaletteCrop, pc
    assert_equal crop.id, pc.id
    assert_equal "Carrot", pc.name
    assert_equal "V1", pc.variety
  end

  test "find_private_cultivation_plan_detail maps fields and field cultivations into read structs" do
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

    dto = @gateway.find_private_cultivation_plan_detail(user: user, plan_id: plan.id)

    assert_equal 1, dto.field_cultivations_count
    assert_equal 1, dto.cultivation_plan_fields_count
    assert_equal 1, dto.field_cultivations.size
    row = dto.field_cultivations.first
    assert_instance_of Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::FieldCultivationRead, row
    assert_equal fc.id, row.id
    assert_equal field.id, row.cultivation_plan_field_id
    assert_equal fc.field_display_name, row.field_display_name
    assert_equal plan_crop.id, row.cultivation_plan_crop_id
    assert_equal fc.crop_display_name, row.crop_display_name
    assert_equal fc.start_date, row.start_date
    assert_equal fc.completion_date, row.completion_date
    assert_equal 42, row.optimization_profit

    assert_equal 1, dto.cultivation_plan_fields.size
    fr = dto.cultivation_plan_fields.first
    assert_instance_of Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail::PlanFieldRead, fr
    assert_equal field.id, fr.id
    assert_equal "North", fr.name
    assert_in_delta 50.0, fr.area.to_f, 0.001
  end

  test "find_private_cultivation_plan_detail raises domain RecordNotFound when plan belongs to another user" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private")

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_private_cultivation_plan_detail(user: other, plan_id: plan.id)
    end
  end

  test "find_private_cultivation_plan_detail raises domain RecordNotFound when id missing" do
    user = create(:user)

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      @gateway.find_private_cultivation_plan_detail(user: user, plan_id: 9_999_999)
    end
  end

  test "public_plan_results_snapshot show_schedule_warning is false when plan has no field cultivations" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)

    rm = @gateway.public_plan_results_snapshot(plan_id: plan.id)
    assert_not_nil rm
    assert_equal false, rm.show_schedule_warning
  end

  test "public_plan_results_snapshot show_schedule_warning is false when every field cultivation has schedule with items" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
    crop = create(:crop, :reference)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: "A", area: 10)
    fc = create(:field_cultivation, cultivation_plan: plan, cultivation_plan_field: field, cultivation_plan_crop: plan_crop)
    schedule = create(:task_schedule, cultivation_plan: plan, field_cultivation: fc)
    create(:task_schedule_item, task_schedule: schedule)

    rm = @gateway.public_plan_results_snapshot(plan_id: plan.id)
    assert_not_nil rm
    assert_equal false, rm.show_schedule_warning
  end

  test "public_plan_results_snapshot show_schedule_warning is true when some field cultivation lacks schedule items" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
    crop = create(:crop, :reference)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: "A", area: 10)
    field2 = create(:cultivation_plan_field, cultivation_plan: plan, name: "B", area: 20)
    fc1 = create(:field_cultivation, cultivation_plan: plan, cultivation_plan_field: field1, cultivation_plan_crop: plan_crop)
    create(:field_cultivation, cultivation_plan: plan, cultivation_plan_field: field2, cultivation_plan_crop: plan_crop)
    schedule = create(:task_schedule, cultivation_plan: plan, field_cultivation: fc1)
    create(:task_schedule_item, task_schedule: schedule)

    rm = @gateway.public_plan_results_snapshot(plan_id: plan.id)
    assert_not_nil rm
    assert_equal true, rm.show_schedule_warning
  end

  test "public_plan_results_snapshot show_schedule_warning is true when schedule has no items" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
    crop = create(:crop, :reference)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: "A", area: 10)
    fc = create(:field_cultivation, cultivation_plan: plan, cultivation_plan_field: field, cultivation_plan_crop: plan_crop)
    create(:task_schedule, cultivation_plan: plan, field_cultivation: fc)

    rm = @gateway.public_plan_results_snapshot(plan_id: plan.id)
    assert_not_nil rm
    assert_equal true, rm.show_schedule_warning
  end

  test "public_plan_wizard_save_session_payload returns nil when plan missing" do
    assert_nil @gateway.public_plan_wizard_save_session_payload(plan_id: 9_999_999, farm_id: 1, crop_ids: [ 2 ])
  end

  test "public_plan_wizard_save_session_payload mirrors field_data and passes session ids through" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
    create(:cultivation_plan_field, cultivation_plan: plan, name: "North", area: 50.5, daily_fixed_cost: 1)
    payload = @gateway.public_plan_wizard_save_session_payload(plan_id: plan.id, farm_id: 99, crop_ids: [ 7, 8 ])

    assert_equal plan.id, payload[:plan_id]
    assert_equal 99, payload[:farm_id]
    assert_equal [ 7, 8 ], payload[:crop_ids]
    assert_equal 1, payload[:field_data].size
    row = payload[:field_data].first
    assert_equal "North", row[:name]
    assert_in_delta 50.5, row[:area].to_f, 0.001
    assert_equal [ 35.0, 139.0 ], row[:coordinates]
  end

  test "public_plan_wizard_plan_exists? is false when id missing or unknown" do
    assert_equal false, @gateway.public_plan_wizard_plan_exists?(plan_id: nil)
    assert_equal false, @gateway.public_plan_wizard_plan_exists?(plan_id: 9_999_999_999)
  end

  test "public_plan_wizard_plan_exists? is true when plan exists" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, farm: farm)

    assert_equal true, @gateway.public_plan_wizard_plan_exists?(plan_id: plan.id)
  end

  test "public_plan_results_snapshot returns nil when plan missing" do
    assert_nil @gateway.public_plan_results_snapshot(plan_id: 9_999_999_999)
  end

  test "public_plan_results_snapshot returns snapshot with gantt rows and palette" do
    farm = create(:farm, region: "jp")
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm, total_cost: 100, total_revenue: 200, total_profit: 100)
    crop = create(:crop, :reference, region: "jp", name: "Alpha Crop")
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)
    field = create(:cultivation_plan_field, cultivation_plan: plan, name: "Plot1", area: 10)
    create(:field_cultivation, cultivation_plan: plan, cultivation_plan_field: field, cultivation_plan_crop: plan_crop)

    rm = @gateway.public_plan_results_snapshot(plan_id: plan.id)
    assert_not_nil rm
    assert_equal plan.id, rm.plan_id
    assert_equal true, rm.status_completed
    assert_equal farm.name, rm.farm_name
    assert_equal 1, rm.field_cultivations_count
    assert_equal 1, rm.gantt_cultivation_rows.size
    assert_equal 1, rm.gantt_field_rows.size
    assert_equal crop.id, rm.crop_palette_embed[:used_crop_ids].first
    crop_names = rm.crop_palette_embed[:crops].map { |h| h[:name] }
    assert_includes crop_names, "Alpha Crop"
  end
end
