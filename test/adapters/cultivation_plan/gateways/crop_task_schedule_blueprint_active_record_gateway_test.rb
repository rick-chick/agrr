# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintActiveRecordGatewayTest < ActiveSupport::TestCase
  include PlanSaveTestSupport

  setup do
    @gateway = ::Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintActiveRecordGateway.new
  end

  test "list_by_crop_id returns blueprint rows for crop" do
    ref_crop = build_reference_crop(name: "BpList#{SecureRandom.hex(4)}")
    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "BpTk#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.0
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

    rows = @gateway.list_by_crop_id(crop_id: ref_crop.id)

    assert_equal 1, rows.size
    assert_equal ref_task.id, rows.first.agricultural_task_id
    assert_in_delta 5.0, rows.first.gdd_trigger.to_f, 0.001
  end

  test "bulk_create persists records readable by list_by_crop_id" do
    user = unique_test_user
    user_crop = user.crops.create!(
      name: "BpCr#{SecureRandom.hex(4)}",
      variety: "v",
      is_reference: false,
      area_per_unit: 0.2,
      revenue_per_area: 100.0,
      region: "jp"
    )
    user_task = user.agricultural_tasks.create!(
      name: "BpUt#{SecureRandom.hex(4)}",
      is_reference: false,
      region: "jp",
      time_per_sqm: 1.0
    )

    @gateway.bulk_create(
      records: [
        Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintCreateAttrs.new(
          crop_id: user_crop.id,
          agricultural_task_id: user_task.id,
          source_agricultural_task_id: user_task.id,
          stage_order: 0,
          stage_name: "苗",
          gdd_trigger: 3.0,
          gdd_tolerance: nil,
          task_type: TaskScheduleItem::FIELD_WORK_TYPE,
          source: "agrr",
          priority: 1,
          amount: nil,
          amount_unit: nil,
          description: nil,
          weather_dependency: nil,
          time_per_sqm: 1.0
        )
      ]
    )

    rows = @gateway.list_by_crop_id(crop_id: user_crop.id)
    assert_equal 1, rows.size
    assert_equal user_task.id, rows.first.agricultural_task_id
  end

  test "delete_by_crop_id removes blueprints for crop" do
    ref_crop = build_reference_crop(name: "BpDel#{SecureRandom.hex(4)}")
    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "BpTkDel#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.0
    )

    CropTaskScheduleBlueprint.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      stage_order: 0,
      stage_name: "苗",
      gdd_trigger: 1,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: "agrr",
      priority: 1,
      time_per_sqm: 1.0
    )

    @gateway.delete_by_crop_id(crop_id: ref_crop.id)

    assert_empty @gateway.list_by_crop_id(crop_id: ref_crop.id)
  end
end
