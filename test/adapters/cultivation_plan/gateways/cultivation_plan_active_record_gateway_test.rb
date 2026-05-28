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

end
