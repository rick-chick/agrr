# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::PestMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies reference pest linked to plan crops and maps ids" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "PestCrop#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop)

    ref_pest = Pest.create!(
      user: nil,
      name: "RefPest#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )
    CropPest.create!(crop: ref_crop, pest: ref_pest)

    result = plan_save_result
    ctx = Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx).create_user_crops_from_plan

    pests = Adapters::CultivationPlan::Mappers::PestMapper.new(ctx).copy_pests_for_region(ref_farm.region)
    assert_equal 1, pests.size
    user_pest = user.pests.find_by(source_pest_id: ref_pest.id)
    assert_not_nil user_pest
    assert_equal user_pest.id, ctx.reference_pest_id_to_user_pest_id[ref_pest.id]
  end

  test "idempotent copy skips existing user pest" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "PestCrop2_#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop, plan_name: "pest2")

    ref_pest = Pest.create!(
      user: nil,
      name: "RefPest2_#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )
    CropPest.create!(crop: ref_crop, pest: ref_pest)

    ctx1 = Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
      user: user,
      session_data: { plan_id: plan.id },
      result: plan_save_result
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx1).create_user_crops_from_plan
    Adapters::CultivationPlan::Mappers::PestMapper.new(ctx1).copy_pests_for_region(ref_farm.region)
    existing = user.pests.find_by(source_pest_id: ref_pest.id)

    result2 = plan_save_result
    ctx2 = Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
      user: user,
      session_data: { plan_id: plan.id },
      result: result2
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx2).create_user_crops_from_plan
    Adapters::CultivationPlan::Mappers::PestMapper.new(ctx2).copy_pests_for_region(ref_farm.region)

    existing_crop = user.crops.find_by(source_crop_id: ref_crop.id)
    assert_skipped_exact result2,
                         { crops: [ existing_crop.id ], pests: user.pests.where.not(source_pest_id: nil).pluck(:id) }
  end
end
