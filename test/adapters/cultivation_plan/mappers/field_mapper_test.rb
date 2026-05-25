# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Mappers::FieldMapperTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  test "creates fields from session when farm is new" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    result = plan_save_result
    ctx = build_plan_save_context(
      user: user,
      session_data: {
        farm_id: ref_farm.id,
        field_data: [
          { name: "区画A", area: 12.5, coordinates: [ 35.0, 139.0 ] }
        ]
      },
      result: result
    )
    farm = stub_user_farm_for_mapper_test(ctx)

    fields = Adapters::CultivationPlan::Mappers::FieldMapper.new(ctx).create_user_fields(farm)
    assert_equal 1, fields.size
    assert_equal "区画A", fields.first.name
    assert_in_delta 12.5, fields.first.area.to_f, 0.001
    assert_equal farm.id, fields.first.farm_id
    assert_equal user.id, fields.first.user_id
  end

  test "reuses existing fields and records skips when farm_reused" do
    user = unique_test_user
    ref_farm = ensure_reference_farm
    session_data = {
      farm_id: ref_farm.id,
      field_data: [ { name: "再利用圃場", area: 3.0 } ]
    }

    result1 = plan_save_result
    ctx1 = build_plan_save_context(user: user, session_data: session_data, result: result1)
    farm1 = stub_user_farm_for_mapper_test(ctx1)
    fields1 = Adapters::CultivationPlan::Mappers::FieldMapper.new(ctx1).create_user_fields(farm1)
    field_id = fields1.first.id

    result2 = plan_save_result
    ctx2 = build_plan_save_context(user: user, session_data: session_data, result: result2)
    farm2 = stub_user_farm_for_mapper_test(ctx2, reuse_existing: true)
    assert ctx2.farm_reused

    fields = Adapters::CultivationPlan::Mappers::FieldMapper.new(ctx2).create_user_fields(farm2)
    assert_equal 1, fields.size
    assert fields.all? { |f| f.persisted? }
    assert_skipped_exact result2, { farm: [ farm2.id ], fields: [ field_id ] }
  end
end
