# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new(
      deletion_undo_gateway: Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new,
      crop_agrr_requirement_builder: Adapters::Crop::Ports::CropAgrrRequirementBuilderAdapter.new
    )
  end

  test "should find existing cultivation plan" do
    user = create(:user)
    farm = create(:farm, user: user)
    existing_plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

    found_plan = @gateway.find_existing(farm, user)

    assert_not_nil found_plan
    assert_equal existing_plan.id, found_plan.id
    assert_instance_of Domain::CultivationPlan::Entities::CultivationPlanEntity, found_plan
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

    found_farm = @gateway.find_by_farm_id(farm.id, user)

    assert_not_nil found_farm
    assert_equal farm.id, found_farm.id
    assert_equal farm.name, found_farm.name
    assert_instance_of Domain::Farm::Entities::FarmEntity, found_farm
  end

  test "should return nil when farm not found" do
    user = create(:user)

    found_farm = @gateway.find_by_farm_id(9999, user)

    assert_nil found_farm
  end

  test "should find crops by ids and user" do
    user = create(:user)
    crop1 = create(:crop, user: user, is_reference: false)
    crop2 = create(:crop, user: user, is_reference: false)
    # 参照作物は除外されるべき（user_idなしで作成）
    create(:crop, :reference)

    found_crops = @gateway.list_by_ids([ crop1.id, crop2.id ], user)

    assert_equal 2, found_crops.length
    assert_instance_of Array, found_crops
    crop_ids = found_crops.map(&:id)
    assert_includes crop_ids, crop1.id
    assert_includes crop_ids, crop2.id
  end

  test "should return empty array when no crops found" do
    user = create(:user)

    found_crops = @gateway.list_by_ids([ 9999 ], user)

    assert_empty found_crops
  end

end
