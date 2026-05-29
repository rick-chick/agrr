# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: POST /api/v1/public_plans/save_plan (authenticated)
class PublicPlanSaveContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @farm = create(:farm, :reference)
    @public_plan = create(:cultivation_plan, :public_plan, farm: @farm)
  end

  test "save_plan returns success when public plan exists" do
    if rust_contract?
      response = rust_post(
        "/api/v1/public_plans/save_plan",
        session_id: @session_id,
        body: { plan_id: @public_plan.id }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      post "/api/v1/public_plans/save_plan",
           params: { plan_id: @public_plan.id },
           headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert json["success"], json.inspect
    assert_nil json["error"]
  end
end
