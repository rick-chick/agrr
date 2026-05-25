# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::PlanSaveFarmActiveRecordGatewayTest < ActiveSupport::TestCase
  include PlanSaveMapperTestSupport

  setup do
    @gateway = Adapters::CultivationPlan::Gateways::PlanSaveFarmActiveRecordGateway.new
  end

  test "create_user_farm_from_reference persists copy and returns FarmEntity" do
    user = unique_test_user
    ref = ensure_reference_farm

    assert_difference -> { Farm.where(user_id: user.id, is_reference: false).count }, 1 do
      entity = @gateway.create_user_farm_from_reference(
        user_id: user.id,
        reference_farm_id: ref.id,
        copy_name_suffix: "20260525_123456"
      )

      assert_instance_of Domain::Farm::Entities::FarmEntity, entity
      assert_equal user.id, entity.user_id
      assert_not entity.is_reference
      assert_includes entity.name, "コピー 20260525_123456"
      assert_equal ref.latitude, entity.latitude
      assert_equal ref.longitude, entity.longitude
    end
  end

  test "find_reference_farm returns nil when missing" do
    assert_nil @gateway.find_reference_farm(farm_id: 0)
  end

  test "find_plan_id_by_user_and_farm returns plan id when present" do
    user = unique_test_user
    ref = ensure_reference_farm
    user_farm = Farm.find(
      @gateway.create_user_farm_from_reference(
        user_id: user.id,
        reference_farm_id: ref.id,
        copy_name_suffix: "20260525_120001"
      ).id
    )
    plan = create(:cultivation_plan, farm: user_farm, user: user)

    assert_equal plan.id, @gateway.find_plan_id_by_user_and_farm(user_id: user.id, farm_id: user_farm.id)
  end

end
