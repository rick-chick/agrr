# frozen_string_literal: true

require "test_helper"

class Domain::CultivationPlan::Mappers::FarmMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "creates user farm from reference and reuses on second call with skip recorded" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    result = plan_save_result
    ctx = Domain::CultivationPlan::PlanSaveContext.new(
      user: user,
      session_data: { farm_id: ref_farm.id },
      result: result
    )
    mapper = Domain::CultivationPlan::Mappers::FarmMapper.new(ctx)

    farm = mapper.create_or_get_user_farm
    assert farm.persisted?
    assert_equal user.id, farm.user_id
    assert_equal ref_farm.id, farm.source_farm_id
    assert_not ctx.farm_reused

    farm_again = mapper.create_or_get_user_farm
    assert_equal farm.id, farm_again.id
    assert ctx.farm_reused
    assert_includes result.skipped_items[:farm], farm.id
  end
end
