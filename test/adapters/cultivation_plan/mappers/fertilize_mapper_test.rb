# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::FertilizeMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "copies reference fertilize for region" do
    user = unique_test_user
    name = "RefFert#{SecureRandom.hex(4)}"
    ref_f = Fertilize.create!(
      user: nil,
      name: name,
      n: 10,
      p: 5,
      k: 8,
      is_reference: true,
      region: "jp"
    )

    result = plan_save_result
    ctx = build_plan_save_context(user: user, session_data: {}, result: result)
    list = Adapters::CultivationPlan::Mappers::FertilizeMapper.new(ctx).copy_fertilizes_for_region("jp")

    assert(list.any? { |f| f.source_fertilize_id == ref_f.id })
    user_f = user.fertilizes.find_by(source_fertilize_id: ref_f.id)
    assert_not_nil user_f
    assert_includes user_f.name, "コピー"
  end

  test "skips when user already owns copy of reference fertilize" do
    user = unique_test_user
    name = "RefFert2_#{SecureRandom.hex(4)}"
    ref_f = Fertilize.create!(
      user: nil,
      name: name,
      n: 1,
      p: 1,
      k: 1,
      is_reference: true,
      region: "jp"
    )

    result1 = plan_save_result
    ctx1 = build_plan_save_context(user: user, session_data: {}, result: result1)
    Adapters::CultivationPlan::Mappers::FertilizeMapper.new(ctx1).copy_fertilizes_for_region("jp")
    existing = user.fertilizes.find_by(source_fertilize_id: ref_f.id)

    result2 = plan_save_result
    ctx2 = build_plan_save_context(user: user, session_data: {}, result: result2)
    Adapters::CultivationPlan::Mappers::FertilizeMapper.new(ctx2).copy_fertilizes_for_region("jp")

    assert_skipped_exact result2, { fertilizes: user.fertilizes.where.not(source_fertilize_id: nil).pluck(:id) }
  end
end
