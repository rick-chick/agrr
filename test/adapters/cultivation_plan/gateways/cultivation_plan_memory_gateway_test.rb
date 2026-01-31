# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanMemoryGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanMemoryGateway.new
  end

  test "should create cultivation plan" do
    user = create(:user)
    farm = create(:farm, user: user)
    crop = create(:crop, user: user, is_reference: false)

    create_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateGatewayDto.new(
      farm: farm,
      crops: [crop],
      user: user,
      plan_name: "Test Plan",
      total_area: 100.0
    )

    result = @gateway.create(create_dto)

    assert result.success?
    assert_not_nil result.cultivation_plan
    assert_equal "Test Plan", result.cultivation_plan.plan_name
    assert_equal user.id, result.cultivation_plan.user_id
    assert_equal farm.id, result.cultivation_plan.farm_id
    assert_equal "private", result.cultivation_plan.plan_type
  end

  test "should find existing cultivation plan" do
    user = create(:user)
    farm = create(:farm, user: user)
    existing_plan = create(:cultivation_plan, farm: farm, user: user, plan_type: 'private')

    found_plan = @gateway.find_existing(farm, user)

    assert_not_nil found_plan
    assert_equal existing_plan.id, found_plan.id
    assert_instance_of ::CultivationPlan, found_plan
  end

  test "should return nil when no existing plan found" do
    user = create(:user)
    farm = create(:farm, user: user)

    found_plan = @gateway.find_existing(farm, user)

    assert_nil found_plan
  end

  test "should find farm by id and user" do
    user = create(:user)
    farm = create(:farm, user: user)

    found_farm = @gateway.find_farm(farm.id, user)

    assert_not_nil found_farm
    assert_equal farm.id, found_farm.id
    assert_equal farm.name, found_farm.name
    assert_instance_of ::Farm, found_farm
  end

  test "should return nil when farm not found" do
    user = create(:user)

    found_farm = @gateway.find_farm(9999, user)

    assert_nil found_farm
  end

  test "should find crops by ids and user" do
    user = create(:user)
    crop1 = create(:crop, user: user, is_reference: false)
    crop2 = create(:crop, user: user, is_reference: false)
    # 参照作物は除外されるべき（user_idなしで作成）
    create(:crop, :reference)

    found_crops = @gateway.find_crops([crop1.id, crop2.id], user)

    assert_equal 2, found_crops.length
    assert_instance_of Array, found_crops
    crop_ids = found_crops.map(&:id)
    assert_includes crop_ids, crop1.id
    assert_includes crop_ids, crop2.id
  end

  test "should return empty array when no crops found" do
    user = create(:user)

    found_crops = @gateway.find_crops([9999], user)

    assert_empty found_crops
  end

  test "should raise error when create fails" do
    user = create(:user)
    farm = create(:farm, user: user)
    crop = create(:crop, user: user, is_reference: false)

    # 同じfarm×userの計画が既に存在する場合
    create(:cultivation_plan, farm: farm, user: user, plan_type: 'private')

    create_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateGatewayDto.new(
      farm: farm,
      crops: [crop],
      user: user,
      plan_name: "Test Plan",
      total_area: 100.0
    )

    assert_raises(StandardError) do
      @gateway.create(create_dto)
    end
  end
end