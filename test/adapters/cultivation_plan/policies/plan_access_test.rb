# frozen_string_literal: true

require "test_helper"

class Domain::CultivationPlan::Policies::PlanAccessTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @other = create(:user)
    @farm = create(:farm, user: @user)
    @private_plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
  end

  test "find_private_owned! returns plan for owner" do
    plan = Domain::CultivationPlan::Policies::PlanAccess.find_private_owned!(@user, @private_plan.id)

    assert_equal @private_plan.id, plan.id
  end

  test "find_private_owned! raises RecordNotFound when plan id missing" do
    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      Domain::CultivationPlan::Policies::PlanAccess.find_private_owned!(@user, 9_999_999)
    end
  end

  test "find_private_owned! raises PolicyPermissionDenied for other users private plan" do
    other_farm = create(:farm, user: @other)
    other_plan = create(:cultivation_plan, :annual_planning, farm: other_farm, user: @other, plan_type: :private)

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::CultivationPlan::Policies::PlanAccess.find_private_owned!(@user, other_plan.id)
    end
  end

  test "find_private_owned! raises PolicyPermissionDenied for public plan" do
    public_farm = create(:farm, user: @user)
    public_plan = create(:cultivation_plan, :annual_planning, farm: public_farm, user: @user, plan_type: :public)

    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::CultivationPlan::Policies::PlanAccess.find_private_owned!(@user, public_plan.id)
    end
  end

  test "find_public! returns public plan" do
    public_farm = create(:farm, user: @user)
    public_plan = create(:cultivation_plan, :annual_planning, farm: public_farm, user: @user, plan_type: :public)

    plan = Domain::CultivationPlan::Policies::PlanAccess.find_public!(public_plan.id)

    assert_equal public_plan.id, plan.id
  end

  test "find_public! raises PolicyPermissionDenied for private plan" do
    assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
      Domain::CultivationPlan::Policies::PlanAccess.find_public!(@private_plan.id)
    end
  end
end
