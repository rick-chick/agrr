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
    assert json.key?("cultivation_plan_id"), json.inspect
    assert_equal false, json["plan_reused"]
  end

  test "save_plan returns plan_reused on second save for same farm" do
    first_json = nil
    if rust_contract?
      first_response = rust_post(
        "/api/v1/public_plans/save_plan",
        session_id: @session_id,
        body: { plan_id: @public_plan.id }
      )
      assert_equal 200, first_response.code.to_i, first_response.body
      first_json = JSON.parse(first_response.body)
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
      first_json = JSON.parse(body)
      post "/api/v1/public_plans/save_plan",
           params: { plan_id: @public_plan.id },
           headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert first_json["success"], first_json.inspect
    assert first_json["cultivation_plan_id"].present?
    assert_equal false, first_json["plan_reused"]

    assert json["success"], json.inspect
    assert json["plan_reused"], json.inspect
    assert json["cultivation_plan_id"].present?
    assert_equal first_json["cultivation_plan_id"], json["cultivation_plan_id"],
                 "Second save should return the same private cultivation_plan_id"
  end

  test "save_plan then private plan data includes cultivations when public plan has field cultivations" do
    setup_public_plan_with_field_cultivation!

    if rust_contract?
      save_response = rust_post(
        "/api/v1/public_plans/save_plan",
        session_id: @session_id,
        body: { plan_id: @public_plan.id }
      )
      assert_equal 200, save_response.code.to_i, save_response.body
      save_json = JSON.parse(save_response.body)
      private_plan_id = save_json["cultivation_plan_id"]
      data_response = rust_get(
        "/api/v1/plans/cultivation_plans/#{private_plan_id}/data",
        session_id: @session_id
      )
      assert_equal 200, data_response.code.to_i, data_response.body
      data_json = JSON.parse(data_response.body)
    else
      sign_in_as @user
      post "/api/v1/public_plans/save_plan",
           params: { plan_id: @public_plan.id },
           headers: { "Accept" => "application/json" }
      assert_response :success
      save_json = JSON.parse(body)
      private_plan_id = save_json["cultivation_plan_id"]
      get "/api/v1/plans/cultivation_plans/#{private_plan_id}/data",
          headers: { "Accept" => "application/json" }
      assert_response :success
      data_json = JSON.parse(body)
    end

    assert save_json["success"], save_json.inspect
    assert private_plan_id.present?
    assert data_json["success"], data_json.inspect
    cultivations = data_json.dig("data", "cultivations")
    assert cultivations.is_a?(Array), data_json.inspect
    assert cultivations.any?, "saved private plan must expose cultivations for gantt"
  end

  private

  def setup_public_plan_with_field_cultivation!
    @reference_crop = create(:crop, :reference, region: @farm.region)
    @public_plan = create(:cultivation_plan, :public_plan, :completed, farm: @farm)
    @plan_field = create(:cultivation_plan_field, cultivation_plan: @public_plan)
    @plan_crop = create(:cultivation_plan_crop, cultivation_plan: @public_plan, crop: @reference_crop)
    create(:field_cultivation,
      cultivation_plan: @public_plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      status: "completed")
  end
end
