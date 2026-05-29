# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class FieldCultivationPatchContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @plan = create(:cultivation_plan, :annual_planning, farm: @farm, user: @user, plan_type: "private", status: "completed")
    @field = create(:cultivation_plan_field, cultivation_plan: @plan, name: "F1", area: 100.0, daily_fixed_cost: 1.0)
    @crop = create(:crop, :user_owned, user: @user)
    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: @crop, name: @crop.name)
    @fc = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 4, 1),
      completion_date: Date.new(2026, 10, 31),
      area: 10.0,
      status: "completed")
    @session_id = contract_session_id_for(@user)
  end

  test "patch field cultivation schedule returns success shape" do
    body = {
      field_cultivation: {
        start_date: "2026-05-01",
        completion_date: "2026-11-30"
      }
    }
    if rust_contract?
      response = rust_patch(
        "/api/v1/plans/field_cultivations/#{@fc.id}",
        session_id: @session_id,
        body: body
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert json["success"]
      assert_equal @fc.id, json.dig("field_cultivation", "id")
    else
      patch "/api/v1/plans/field_cultivations/#{@fc.id}",
            params: body,
            headers: { "Cookie" => "session_id=#{@session_id}" },
            as: :json
      assert_response :success
      json = JSON.parse(response.body)
      assert json["success"]
    end
  end
end
