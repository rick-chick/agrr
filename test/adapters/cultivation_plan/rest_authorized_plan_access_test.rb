# frozen_string_literal: true

require "test_helper"

class Adapters::CultivationPlan::RestAuthorizedPlanAccessTest < ActiveSupport::TestCase
  test "find! public resolves plan visible under PlanPolicy.public_scope" do
    farm = create(:farm, :reference)
    plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
    auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

    found = Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan.id)

    assert_equal plan.id, found.id
    assert_predicate found, :plan_type_public?
  end

  test "find! public raises RecordNotFound when id absent" do
    auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

    assert_raises(ActiveRecord::RecordNotFound) do
      Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, 9_999_999_999)
    end
  end

  test "find! public does not expose private plans" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")
    auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

    assert_raises(ActiveRecord::RecordNotFound) do
      Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan.id)
    end
  end

  test "find! private loads plan owned by authenticated user" do
    user = create(:user)
    farm = create(:farm, user: user)
    plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")
    auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: user.id)

    found = Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan.id)

    assert_equal plan.id, found.id
  end

  test "find! private raises RecordNotFound for another users plan" do
    owner = create(:user)
    other = create(:user)
    farm = create(:farm, user: owner)
    plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private", status: "completed")
    auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: other.id)

    assert_raises(ActiveRecord::RecordNotFound) do
      Adapters::CultivationPlan::RestAuthorizedPlanAccess.find!(auth, plan.id)
    end
  end
end
