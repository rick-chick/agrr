# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors Api::V1::Plans::CultivationPlansController#data (private workbench payload)
class PrivateCultivationPlanDataContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @plan = create(:cultivation_plan, :annual_planning, :completed,
      farm: @farm,
      user: @user,
      plan_type: :private)
    @field = create(:cultivation_plan_field, cultivation_plan: @plan)
    @crop = create(:crop, :user_owned, user: @user)
    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop)
    create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @plan_crop,
      status: "completed")
    @session_id = Session.create_for_user(@user).session_id
  end

  test "data returns workbench payload for owner" do
    path = "/api/v1/plans/cultivation_plans/#{@plan.id}/data"
    response = rust_get(path, session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert json["success"]
    assert_equal @plan.id, json["data"]["id"]
    assert json["data"]["cultivations"].is_a?(Array)
  end

  test "data returns not found for another user's plan" do
    other = create(:user)
    other_farm = create(:farm, user: other)
    other_plan = create(:cultivation_plan, :annual_planning, farm: other_farm, user: other, plan_type: :private)

    path = "/api/v1/plans/cultivation_plans/#{other_plan.id}/data"
    response = rust_get(path, session_id: @session_id)
    assert_equal 404, response.code.to_i, response.body
    json = JSON.parse(response.body)
    refute json["success"]
  end

  test "data returns unauthorized when not authenticated" do
    path = "/api/v1/plans/cultivation_plans/#{@plan.id}/data"
    response = rust_get(path)
    assert_equal 401, response.code.to_i
  end
end
