# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::PlanSaveFarmActiveRecordGatewayTest < ActiveSupport::TestCase
  include PlanSaveTestSupport

  setup do
    @gateway = Adapters::CultivationPlan::Gateways::PlanSaveFarmActiveRecordGateway.new
  end

  test "create_user_farm_from_reference persists copy and returns PlanSaveUserFarmSnapshot" do
    user = unique_test_user
    ref = ensure_reference_farm

    assert_difference -> { Farm.where(user_id: user.id, is_reference: false).count }, 1 do
      snapshot = @gateway.create_user_farm_from_reference(
        user_id: user.id,
        reference_farm_id: ref.id,
        copy_name_suffix: "20260525_123456"
      )

      assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveUserFarmSnapshot, snapshot
      assert_includes snapshot.name, "コピー 20260525_123456"

      record = Farm.find(snapshot.id)
      assert_equal user.id, record.user_id
      assert_not record.is_reference
      assert_equal ref.latitude, record.latitude
      assert_equal ref.longitude, record.longitude
    end
  end

  test "find_reference_farm returns PlanSaveReferenceFarmSnapshot" do
    ref = ensure_reference_farm

    snapshot = @gateway.find_reference_farm(farm_id: ref.id)

    assert_instance_of Domain::CultivationPlan::Dtos::PlanSaveReferenceFarmSnapshot, snapshot
    assert_equal ref.id, snapshot.id
    assert_equal ref.name, snapshot.name
    assert_equal ref.region, snapshot.region
  end

  test "find_reference_farm returns nil when missing" do
    assert_nil @gateway.find_reference_farm(farm_id: 0)
  end

  test "find_owned_farm_record returns farm scoped to user" do
    user = unique_test_user
    ref = ensure_reference_farm
    entity = @gateway.create_user_farm_from_reference(
      user_id: user.id,
      reference_farm_id: ref.id,
      copy_name_suffix: "20260525_120001"
    )

    record = @gateway.find_owned_farm_record(user_id: user.id, farm_id: entity.id)

    assert_not_nil record
    assert_equal entity.id, record.id
    assert_equal user.id, record.user_id
    assert_nil @gateway.find_owned_farm_record(user_id: user.id, farm_id: 0)
  end

  test "find_owned_private_plan_record returns private plan for user and farm" do
    user = unique_test_user
    ref = ensure_reference_farm
    user_farm = Farm.find(
      @gateway.create_user_farm_from_reference(
        user_id: user.id,
        reference_farm_id: ref.id,
        copy_name_suffix: "20260525_120002"
      ).id
    )
    plan = create(:cultivation_plan, farm: user_farm, user: user)

    found = @gateway.find_owned_private_plan_record(user_id: user.id, farm_id: user_farm.id)

    assert_equal plan, found
    assert_nil @gateway.find_owned_private_plan_record(user_id: user.id, farm_id: 0)
  end

end
