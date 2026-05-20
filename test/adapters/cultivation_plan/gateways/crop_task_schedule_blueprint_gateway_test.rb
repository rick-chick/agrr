# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintGatewayTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copy_for_user_crops inserts blueprints for mapped user crop" do
    user = unique_test_user
    ref_crop = build_reference_crop(name: "BpCr#{SecureRandom.hex(4)}")
    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "BpTk#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.0
    )

    user_crop = user.crops.create!(
      name: ref_crop.name,
      variety: ref_crop.variety,
      area_per_unit: ref_crop.area_per_unit,
      revenue_per_area: ref_crop.revenue_per_area,
      groups: ref_crop.groups,
      is_reference: false,
      region: ref_crop.region,
      source_crop_id: ref_crop.id
    )
    user_task = user.agricultural_tasks.create!(
      name: ref_task.name,
      description: ref_task.description,
      time_per_sqm: ref_task.time_per_sqm,
      weather_dependency: ref_task.weather_dependency,
      required_tools: ref_task.required_tools,
      skill_level: ref_task.skill_level,
      task_type: ref_task.task_type,
      task_type_id: ref_task.task_type_id,
      region: ref_task.region,
      is_reference: false,
      source_agricultural_task_id: ref_task.id
    )

    CropTaskScheduleBlueprint.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      stage_order: 0,
      stage_name: "苗",
      gdd_trigger: 5,
      gdd_tolerance: 1,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: "agrr",
      priority: 1,
      time_per_sqm: 1.0
    )

    result = plan_save_result
    ctx = build_plan_save_context(user: user, session_data: {}, result: result)
    ctx.reference_crop_id_to_user_crop_id[ref_crop.id] = user_crop.id

    ::Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintGateway.new(ctx).copy_for_user_crops

    bps = CropTaskScheduleBlueprint.where(crop_id: user_crop.id).order(:stage_order)
    assert_equal 1, bps.count
    assert_equal user_task.id, bps.first.agricultural_task_id
    assert_in_delta 5.0, bps.first.gdd_trigger.to_f, 0.001
  end

  test "copy_for_user_crops replaces existing blueprints idempotently" do
    user = unique_test_user
    ref_crop = build_reference_crop(name: "BpId#{SecureRandom.hex(4)}")
    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "BpTk2_#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.0
    )

    user_crop = user.crops.create!(
      name: ref_crop.name,
      variety: ref_crop.variety,
      area_per_unit: ref_crop.area_per_unit,
      revenue_per_area: ref_crop.revenue_per_area,
      groups: ref_crop.groups,
      is_reference: false,
      region: ref_crop.region,
      source_crop_id: ref_crop.id
    )
    user.agricultural_tasks.create!(
      name: ref_task.name,
      description: ref_task.description,
      time_per_sqm: ref_task.time_per_sqm,
      weather_dependency: ref_task.weather_dependency,
      required_tools: ref_task.required_tools,
      skill_level: ref_task.skill_level,
      task_type: ref_task.task_type,
      task_type_id: ref_task.task_type_id,
      region: ref_task.region,
      is_reference: false,
      source_agricultural_task_id: ref_task.id
    )

    CropTaskScheduleBlueprint.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      stage_order: 0,
      stage_name: "苗",
      gdd_trigger: 3,
      gdd_tolerance: nil,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: "agrr",
      priority: 1,
      time_per_sqm: 1.0
    )

    result = plan_save_result
    ctx = build_plan_save_context(user: user, session_data: {}, result: result)
    ctx.reference_crop_id_to_user_crop_id[ref_crop.id] = user_crop.id

    gw = ::Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintGateway
    gw.new(ctx).copy_for_user_crops
    gw.new(ctx).copy_for_user_crops

    assert_equal 1, CropTaskScheduleBlueprint.where(crop_id: user_crop.id).count
  end
end
