# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors test/controllers/api/v1/plans_controller_test.rb "show returns specific plan"
class PrivateOwnedPlanShowContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @crop = create(:crop, :user_owned, user: @user)
    @plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
    @session_id = Session.create_for_user(@user).session_id
  end

  test "show returns specific plan" do
    if rust_contract?
      response = rust_get("/api/v1/plans/#{@plan.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/plans/#{@plan.id}", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert_equal @plan.id, json["id"]
    assert_equal @plan.display_name, json["name"]
    assert_equal @plan.status, json["status"]
  end

  test "show returns not found for missing plan" do
    if rust_contract?
      response = rust_get("/api/v1/plans/99999999", session_id: @session_id)
      assert_equal 404, response.code.to_i
      json = JSON.parse(response.body)
      assert_equal "Plan not found", json["error"]
    else
      sign_in_as @user
      get "/api/v1/plans/99999999", headers: { "Accept" => "application/json" }
      assert_response :not_found
    end
  end

  test "show returns not found for another user's plan" do
    other_user = create(:user)
    other_farm = create(:farm, user: other_user)
    other_plan = create(:cultivation_plan, :annual_planning, farm: other_farm, user: other_user, plan_type: :private)

    if rust_contract?
      response = rust_get("/api/v1/plans/#{other_plan.id}", session_id: @session_id)
      assert_equal 404, response.code.to_i
      json = JSON.parse(response.body)
      assert_equal "Plan not found", json["error"]
    else
      sign_in_as @user
      get "/api/v1/plans/#{other_plan.id}", headers: { "Accept" => "application/json" }
      assert_response :not_found
    end
  end

  test "show returns unauthorized when not authenticated" do
    if rust_contract?
      response = rust_get("/api/v1/plans/#{@plan.id}")
      assert_equal 401, response.code.to_i
    else
      get "/api/v1/plans/#{@plan.id}", headers: { "Accept" => "application/json" }
      assert_response :unauthorized
    end
  end
end
