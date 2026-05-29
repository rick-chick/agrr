# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors test/controllers/api/v1/plans_controller_test.rb "index returns user's private plans"
class PrivateOwnedPlansIndexContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @farm2 = create(:farm, user: @user)
    @plan1 = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: :private)
    @plan2 = create(:cultivation_plan, :annual_planning, farm: @farm2, user: @user, plan_type: :private)
    @session_id = Session.create_for_user(@user).session_id
  end

  test "index returns user's private plans" do
    if rust_contract?
      response = rust_get("/api/v1/plans", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/plans", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert_equal 2, json.length
    plan_ids = json.map { |p| p["id"] }
    assert_includes plan_ids, @plan1.id
    assert_includes plan_ids, @plan2.id
  end

  test "index returns unauthorized when not authenticated" do
    if rust_contract?
      response = rust_get("/api/v1/plans")
      assert_equal 401, response.code.to_i
    else
      get "/api/v1/plans", headers: { "Accept" => "application/json" }
      assert_response :unauthorized
    end
  end
end
