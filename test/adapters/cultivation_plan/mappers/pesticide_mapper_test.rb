# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::PesticideMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies reference pesticide when crop and pest id maps are on context" do
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
    ctx = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result
    )
    stub_plan_save_crop_mappings_for_mapper_test(ctx, ref_crop: ref_crop)
    stub_plan_save_pest_mappings_for_mapper_test(ctx, ref_pest: ref_pest, ref_crop: ref_crop)

    list = Adapters::CultivationPlan::Mappers::PesticideMapper.new(ctx).copy_pesticides_for_region(ref_farm.region)
    assert(list.any? { |p| p.source_pesticide_id == ref_pesticide.id })
    user_pz = user.pesticides.find_by(source_pesticide_id: ref_pesticide.id)
    assert_not_nil user_pz
    assert_equal user.id, user_pz.user_id
  end

  test "skips existing user pesticide on second mapper run" do
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

    run_pesticide_copy = lambda do |res|
      c = build_plan_save_context(
        user: user,
        session_data: { plan_id: plan.id },
        result: res
      )
      stub_plan_save_crop_mappings_for_mapper_test(c, ref_crop: ref_crop)
      stub_plan_save_pest_mappings_for_mapper_test(c, ref_pest: ref_pest, ref_crop: ref_crop)
      Adapters::CultivationPlan::Mappers::PesticideMapper.new(c).copy_pesticides_for_region(ref_farm.region)
    end

    run_pesticide_copy.call(plan_save_result)
    existing_pesticide = user.pesticides.find_by!(source_pesticide_id: ref_pesticide.id)
    user_crop = user.crops.find_by!(source_crop_id: ref_crop.id)
    user_pest = user.pests.find_by!(source_pest_id: ref_pest.id)

    result2 = plan_save_result
    ctx2 = build_plan_save_context(
      user: user,
      session_data: { plan_id: plan.id },
      result: result2
    )
    ctx2.reference_crop_id_to_user_crop_id = { ref_crop.id => user_crop.id }
    ctx2.reference_pest_id_to_user_pest_id = { ref_pest.id => user_pest.id }
    Adapters::CultivationPlan::Mappers::PesticideMapper.new(ctx2).copy_pesticides_for_region(ref_farm.region)

    assert_skipped_exact result2, { pesticides: [ existing_pesticide.id ] }
  end
end
