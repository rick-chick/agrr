# frozen_string_literal: true

require "test_helper"

class ManageablePublicPlanLookupTest < ActiveSupport::TestCase
  test "returns missing_plan_id when plan_id is nil" do
    result = Adapters::CultivationPlan::ManageablePublicPlanLookup.call(
      plan_id: nil,
      scope: CultivationPlan.all
    )
    assert_equal :missing_plan_id, result[:kind]
  end

  test "returns not_found when plan absent" do
    result = Adapters::CultivationPlan::ManageablePublicPlanLookup.call(
      plan_id: 9_999_999,
      scope: CultivationPlan.all
    )
    assert_equal :not_found, result[:kind]
  end

  test "returns ok with plan when present" do
    farm = create(:farm)
    plan = create(:cultivation_plan, :public_plan, farm: farm)

    result = Adapters::CultivationPlan::ManageablePublicPlanLookup.call(
      plan_id: plan.id,
      scope: CultivationPlan.all
    )

    assert_equal :ok, result[:kind]
    assert_equal plan.id, result[:plan].id
  end
end
