# frozen_string_literal: true

require "test_helper"

# REST add_crop: 作物解決失敗の HTTP 境界（adjust / agrr は踏まない）。
class CultivationPlan::RestAddCropPrivatePlanTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @plan = create(:cultivation_plan, :annual_planning,
      farm: @farm,
      user: @user,
      plan_type: "private",
      status: "completed"
    )
    @field = create(:cultivation_plan_field,
      cultivation_plan: @plan,
      name: "圃場A",
      area: 100.0,
      daily_fixed_cost: 10.0
    )
    sign_in_as @user
  end

  test "returns crop_not_found and does not create plan crop for unknown crop_id" do
    assert_no_difference -> { CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count } do
      post "/api/v1/plans/cultivation_plans/#{@plan.id}/add_crop",
        params: { crop_id: 999_999, field_id: @field.id },
        headers: { "Accept" => "application/json" }
    end

    assert_response :not_found
    json = JSON.parse(response.body)
    refute json["success"]
    assert_equal I18n.t("plans.errors.crop_not_found"), json["message"]
  end
end

class CultivationPlan::RestAddCropPublicPlanTest < ActionDispatch::IntegrationTest
  setup do
    @anonymous_user = User.anonymous_user
    @farm = create(:farm, :reference,
      user: @anonymous_user,
      latitude: 35.6762,
      longitude: 139.6503,
      region: "jp"
    )
    @plan = create(:cultivation_plan,
      farm: @farm,
      user: nil,
      plan_type: "public",
      status: "completed"
    )
    @field = create(:cultivation_plan_field,
      cultivation_plan: @plan,
      name: "公開圃場",
      area: 100.0,
      daily_fixed_cost: 10.0
    )
  end

  test "returns crop_not_found and does not create plan crop for unknown reference crop_id" do
    assert_no_difference -> { CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count } do
      post "/api/v1/public_plans/cultivation_plans/#{@plan.id}/add_crop",
        params: { crop_id: 999_999, field_id: @field.id },
        headers: { "Accept" => "application/json" }
    end

    assert_response :not_found
    json = JSON.parse(response.body)
    refute json["success"]
    assert_equal I18n.t("public_plans.errors.crop_not_found"), json["message"]
  end
end
