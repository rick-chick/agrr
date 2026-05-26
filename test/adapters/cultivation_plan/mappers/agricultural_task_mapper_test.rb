# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::AgriculturalTaskMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies reference task linked to plan crops via crop_task_templates" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "TaskCrop#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop)

    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "RefAgTask#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.5
    )
    CropTaskTemplate.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      name: ref_task.name,
      time_per_sqm: 1.5
    )

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx, ref_crop: ref_crop)

    tasks = Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx).copy_agricultural_tasks_for_region(ref_farm.region)
    assert_equal 1, tasks.size
    user_task = user.agricultural_tasks.find_by(source_agricultural_task_id: ref_task.id)
    assert_not_nil user_task
    assert_equal user_task.id, ctx.reference_agricultural_task_id_to_user_task_id[ref_task.id]
  end

  test "second copy skips existing agricultural task" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "TaskCrop2_#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop, plan_name: "task2")

    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "RefAgTask2_#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 2.0
    )
    CropTaskTemplate.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      name: ref_task.name,
      time_per_sqm: 2.0
    )

    ctx1 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: plan_save_result
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx1, ref_crop: ref_crop)
    Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx1).copy_agricultural_tasks_for_region(ref_farm.region)
    existing = user.agricultural_tasks.find_by(source_agricultural_task_id: ref_task.id)

    result2 = plan_save_result
    ctx2 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result2
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx2, ref_crop: ref_crop)
    Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx2).copy_agricultural_tasks_for_region(ref_farm.region)

    existing_crop = user.crops.find_by(source_crop_id: ref_crop.id)
    assert_skipped_exact result2,
                         { crops: [ existing_crop.id ],
                           agricultural_tasks: user.agricultural_tasks.where.not(source_agricultural_task_id: nil).pluck(:id) }
  end
end
