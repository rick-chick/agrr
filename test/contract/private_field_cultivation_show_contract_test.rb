# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors Api::V1::Plans::FieldCultivationsController#show
class PrivateFieldCultivationShowContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user, latitude: 35.6762, longitude: 139.6503, region: "jp")
    @plan = create(:cultivation_plan, :completed, farm: @farm, user: @user, plan_type: :private)
    @field = create(:cultivation_plan_field, cultivation_plan: @plan)
    @crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: create(:crop, user: @user))
    @field_cultivation = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @crop)
    @session_id = contract_session_id_for(@user)
  end

  test "show returns field cultivation summary" do
    path = "/api/v1/plans/field_cultivations/#{@field_cultivation.id}"
    if rust_contract?
      response = rust_get(path, session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      data = JSON.parse(response.body)
    else
      sign_in_as @user
      get path, headers: { "Accept" => "application/json" }
      assert_response :success
      data = JSON.parse(body)
    end

    assert_equal @field_cultivation.id, data["id"]
    assert_equal @field_cultivation.field_display_name, data["field_name"]
    assert_equal @field_cultivation.crop_display_name, data["crop_name"]
    assert_equal @field_cultivation.area, data["area"]
  end

  test "show returns 404 for another user's field cultivation" do
    other = create(:user)
    other_farm = create(:farm, user: other, latitude: 35.6762, longitude: 139.6503, region: "jp")
    other_plan = create(:cultivation_plan, :completed, farm: other_farm, user: other, plan_type: :private)
    other_field = create(:cultivation_plan_field, cultivation_plan: other_plan)
    other_crop = create(:cultivation_plan_crop, cultivation_plan: other_plan, crop: create(:crop, user: other))
    other_fc = create(:field_cultivation,
      cultivation_plan: other_plan,
      cultivation_plan_field: other_field,
      cultivation_plan_crop: other_crop)

    path = "/api/v1/plans/field_cultivations/#{other_fc.id}"
    if rust_contract?
      response = rust_get(path, session_id: @session_id)
      assert_equal 404, response.code.to_i
    else
      sign_in_as @user
      get path, headers: { "Accept" => "application/json" }
      assert_response :not_found
    end
  end

  test "show returns 401 when not authenticated" do
    path = "/api/v1/plans/field_cultivations/#{@field_cultivation.id}"
    if rust_contract?
      response = rust_get(path)
      assert_equal 401, response.code.to_i
    else
      get path, headers: { "Accept" => "application/json" }
      assert_response :unauthorized
    end
  end
end
