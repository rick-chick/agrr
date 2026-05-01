# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::PesticideMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies reference pesticide when crop and pest mappings exist" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "PzCrop#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop)

    ref_pest = Pest.create!(
      user: nil,
      name: "PzPest#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )
    CropPest.create!(crop: ref_crop, pest: ref_pest)

    ref_pesticide = Pesticide.create!(
      user: nil,
      crop: ref_crop,
      pest: ref_pest,
      name: "Pz#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )

    result = plan_save_result
    ctx = Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    Adapters::CultivationPlan::Mappers::CropMapper.new(ctx).create_user_crops_from_plan
    Adapters::CultivationPlan::Mappers::PestMapper.new(ctx).copy_pests_for_region(ref_farm.region)

    list = Adapters::CultivationPlan::Mappers::PesticideMapper.new(ctx).copy_pesticides_for_region(ref_farm.region)
    assert(list.any? { |p| p.source_pesticide_id == ref_pesticide.id })
    user_pz = user.pesticides.find_by(source_pesticide_id: ref_pesticide.id)
    assert_not_nil user_pz
    assert_equal user.id, user_pz.user_id
  end

  test "skips existing user pesticide on second run" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    ref_crop = build_reference_crop(name: "PzCrop2_#{SecureRandom.hex(4)}")
    plan = build_public_reference_plan(farm: ref_farm, ref_crop: ref_crop, plan_name: "pz2")

    ref_pest = Pest.create!(
      user: nil,
      name: "PzPest2_#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )
    CropPest.create!(crop: ref_crop, pest: ref_pest)
    ref_pesticide = Pesticide.create!(
      user: nil,
      crop: ref_crop,
      pest: ref_pest,
      name: "Pz2_#{SecureRandom.hex(4)}",
      is_reference: true,
      region: "jp"
    )

    run_copy = lambda do |res|
      c = Adapters::CultivationPlan::Sessions::PlanSaveContext.new(
        user: user,
        session_data: { plan_id: plan.id },
        result: res
      )
      Adapters::CultivationPlan::Mappers::CropMapper.new(c).create_user_crops_from_plan
      Adapters::CultivationPlan::Mappers::PestMapper.new(c).copy_pests_for_region(ref_farm.region)
      Adapters::CultivationPlan::Mappers::PesticideMapper.new(c).copy_pesticides_for_region(ref_farm.region)
    end

    run_copy.call(plan_save_result)
    existing = user.pesticides.find_by(source_pesticide_id: ref_pesticide.id)

    result2 = plan_save_result
    run_copy.call(result2)
    existing_crop = user.crops.find_by(source_crop_id: ref_crop.id)
    assert_skipped_exact result2,
                         { crops: [ existing_crop.id ],
                           pests: user.pests.where.not(source_pest_id: nil).pluck(:id),
                           pesticides: user.pesticides.where.not(source_pesticide_id: nil).pluck(:id) }
  end
end
