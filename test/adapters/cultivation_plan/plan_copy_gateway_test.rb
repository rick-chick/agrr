# frozen_string_literal: true

require "test_helper"
require "stringio"

class Adapters::CultivationPlan::PlanCopyGatewayTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copy_cultivation_plan creates private plan owned by user" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_plan = CultivationPlan.create!(
      farm: ref_farm,
      user: nil,
      total_area: 20.0,
      plan_type: "public",
      plan_year: Date.current.year,
      plan_name: "PubGw#{SecureRandom.hex(4)}",
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year,
      status: "completed"
    )

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { farm_id: ref_farm.id, plan_id: ref_plan.id, field_data: [] },
      result: result
    )
    user_farm = Adapters::CultivationPlan::Mappers::FarmMapper.new(ctx).create_or_get_user_farm

    gateway = ::Adapters::CultivationPlan::PlanCopyGateway.new(ctx, logger: CapturingLogger.new)
    new_plan = gateway.copy_cultivation_plan(user_farm, [])

    assert new_plan.persisted?
    assert new_plan.plan_type_private?
    assert_equal user.id, new_plan.user_id
    assert_equal user_farm.id, new_plan.farm_id
  end

  test "copy_plan_relations maps cultivation_plan_crops to user crop ids" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "GwRel#{SecureRandom.hex(4)}")
    ref_plan, cpf, cpc, _fc = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "RelPlan#{SecureRandom.hex(4)}"
    )

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { farm_id: ref_farm.id, plan_id: ref_plan.id, field_data: [] },
      result: result
    )
    user_farm = Adapters::CultivationPlan::Mappers::FarmMapper.new(ctx).create_or_get_user_farm
    crops = Adapters::CultivationPlan::Mappers::CropMapper.new(ctx).create_user_crops_from_plan
    user_crop_id = ctx.ref_cpc_id_to_user_crop_id[cpc.id]
    assert user_crop_id.present?

    gateway = ::Adapters::CultivationPlan::PlanCopyGateway.new(ctx, logger: CapturingLogger.new)
    new_plan = gateway.copy_cultivation_plan(user_farm, crops)
    gateway.establish_master_data_relationships(user_farm, crops, [], [], [], [], [], [])

    gateway.copy_plan_relations(new_plan)

    new_cpc = new_plan.cultivation_plan_crops.find_by(name: ref_crop.name)
    assert_not_nil new_cpc
    assert_equal user_crop_id, new_cpc.crop_id
    assert_equal 1, new_plan.cultivation_plan_fields.where(name: cpf.name).count
  end

  test "copy_task_schedules copies items with user agricultural_task id" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "GwTs#{SecureRandom.hex(4)}")
    ref_plan, _cpf, _cpc, fc = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "TsPlan#{SecureRandom.hex(4)}"
    )

    ref_task = AgriculturalTask.create!(
      user: nil,
      name: "GwAg#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp",
      time_per_sqm: 1.0
    )
    CropTaskTemplate.create!(
      crop: ref_crop,
      agricultural_task: ref_task,
      name: ref_task.name,
      time_per_sqm: 1.0
    )

    ts = TaskSchedule.create!(
      cultivation_plan: ref_plan,
      field_cultivation: fc,
      category: "general",
      status: "active",
      generated_at: Time.current
    )
    TaskScheduleItem.create!(
      task_schedule: ts,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      name: "schedule_item",
      source: "agrr",
      status: TaskScheduleItem::STATUSES[:planned],
      gdd_trigger: 10.0,
      agricultural_task: ref_task
    )

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { farm_id: ref_farm.id, plan_id: ref_plan.id, field_data: [] },
      result: result
    )
    user_farm = Adapters::CultivationPlan::Mappers::FarmMapper.new(ctx).create_or_get_user_farm
    ctx.current_farm_region = user_farm.region
    crops = Adapters::CultivationPlan::Mappers::CropMapper.new(ctx).create_user_crops_from_plan
    tasks = Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx).copy_agricultural_tasks_for_region(user_farm.region)
    user_task = user.agricultural_tasks.find_by(source_agricultural_task_id: ref_task.id)
    assert_not_nil user_task

    gateway = ::Adapters::CultivationPlan::PlanCopyGateway.new(ctx, logger: CapturingLogger.new)
    new_plan = gateway.copy_cultivation_plan(user_farm, crops)
    gateway.establish_master_data_relationships(user_farm, crops, [], [], tasks, [], [], [])

    field_map = gateway.copy_plan_relations(new_plan)
    gateway.copy_task_schedules(new_plan, field_map)

    new_plan.task_schedules.reload
    assert_equal 1, new_plan.task_schedules.count
    item = new_plan.task_schedules.first.task_schedule_items.first
    assert_equal user_task.id, item.agricultural_task_id
  end

  test "copy_private_plan_for_year creates private plan owned by user with copied relations" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "YrCp#{SecureRandom.hex(4)}")
    source_plan, _cpf, _cpc, _fc = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "YrPlan#{SecureRandom.hex(4)}"
    )

    new_year = Date.current.year + 1
    log = CapturingLogger.new
    new_entity = ::Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year(
      source_cultivation_plan_id: source_plan.id,
      new_year: new_year,
      user_id: user.id,
      logger: log
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    assert new_plan.persisted?
    assert new_plan.plan_type_private?
    assert_equal user.id, new_plan.user_id
    assert_equal new_year, new_plan.plan_year
    assert_equal ref_farm.id, new_plan.farm_id
    assert_equal source_plan.cultivation_plan_fields.count, new_plan.cultivation_plan_fields.count
    assert_equal source_plan.cultivation_plan_crops.count, new_plan.cultivation_plan_crops.count
    assert_equal source_plan.field_cultivations.count, new_plan.field_cultivations.count
    assert(
      log.entries.any? { |lvl, msg| lvl == :info && msg.include?("Plan copy completed") },
      "注入 logger に年度コピー完了ログが残ること"
    )
  end

  test "copy_private_plan_for_year sets session_id when given" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "SessCp#{SecureRandom.hex(4)}")
    source_plan, = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "SessPlan#{SecureRandom.hex(4)}"
    )

    sid = "ws-sess-#{SecureRandom.hex(8)}"
    new_entity = ::Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year(
      source_cultivation_plan_id: source_plan.id,
      new_year: Date.current.year + 1,
      user_id: user.id,
      session_id: sid,
      logger: CapturingLogger.new
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    assert_equal sid, new_plan.session_id
  end

  test "copy_private_plan_for_year copies activestorage attachments to new plan" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "AttCp#{SecureRandom.hex(4)}")
    source_plan, = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "AttPlan#{SecureRandom.hex(4)}"
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("dummy"),
      filename: "doc.pdf",
      content_type: "application/pdf"
    )
    ActiveStorage::Attachment.create!(name: "attachments", record: source_plan, blob: blob)

    new_entity = ::Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year(
      source_cultivation_plan_id: source_plan.id,
      new_year: Date.current.year + 2,
      user_id: user.id,
      logger: CapturingLogger.new
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    copied = ActiveStorage::Attachment.where(record: new_plan, name: "attachments")
    assert_equal 1, copied.count
  end

  test "copy_private_plan_for_year keeps attachments after source plan destroyed" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "DesCp#{SecureRandom.hex(4)}")
    source_plan, = build_public_plan_with_field_cultivation(
      farm: ref_farm,
      ref_crop: ref_crop,
      plan_name: "DesPlan#{SecureRandom.hex(4)}"
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("dummy pdf data"),
      filename: "plan.pdf",
      content_type: "application/pdf"
    )
    ActiveStorage::Attachment.create!(name: "attachments", record: source_plan, blob: blob)

    new_entity = ::Adapters::CultivationPlan::PlanCopyGateway.copy_private_plan_for_year(
      source_cultivation_plan_id: source_plan.id,
      new_year: Date.current.year + 2,
      user_id: user.id,
      logger: CapturingLogger.new
    )
    new_plan = ::CultivationPlan.find(new_entity.id)

    source_plan.destroy!
    assert_equal 1,
                 ActiveStorage::Attachment.where(record: new_plan, name: "attachments").count,
                 "元プラン削除後もコピー先の添付が参照可能であること"
  end
end
