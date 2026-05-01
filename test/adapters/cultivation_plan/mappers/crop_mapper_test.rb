# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::CropMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "creates user crops from reference plan and fills id maps" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "MapperCrop#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop)

    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    mapper = Adapters::CultivationPlan::Mappers::CropMapper.new(ctx)
    crops = mapper.create_user_crops_from_plan

    assert_equal 1, crops.size
    user_crop = user.crops.find_by(source_crop_id: ref_crop.id)
    assert_not_nil user_crop
    assert_equal user_crop.id, ctx.reference_crop_id_to_user_crop_id[ref_crop.id]
    cpc = plan.cultivation_plan_crops.first
    assert_equal user_crop.id, ctx.ref_cpc_id_to_user_crop_id[cpc.id]
  end

  test "second run for same user skips existing crops" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "MapperCrop2_#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop, plan_name: "P2")

    ctx1 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: plan_save_result
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx1).create_user_crops_from_plan
    existing = user.crops.find_by(source_crop_id: ref_crop.id)

    result2 = plan_save_result
    ctx2 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result2
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx2).create_user_crops_from_plan

    assert_skipped_exact result2, { crops: [ existing.id ] }
  end
end
