# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: public plan wizard + workbench read endpoints on agrr-server (CONTRACT_RUNTIME=rust).
class PublicPlansApiContractTest < ContractTestCase
  setup do
    @ref_farm = create(:farm, :reference, region: "jp")
    @public_plan = create(:cultivation_plan, :public_plan, :completed, farm: @ref_farm)
    @plan_field = create(:cultivation_plan_field,
      cultivation_plan: @public_plan,
      name: "Contract Field",
      area: 100.0,
      daily_fixed_cost: 10.0)
    @crop = create(:crop, :reference, region: "jp")
    create(:crop_stage, :germination, crop: @crop)
    @plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: @public_plan,
      crop: @crop,
      name: @crop.name,
      variety: @crop.variety)
    create(:field_cultivation,
      cultivation_plan: @public_plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 4, 1),
      completion_date: Date.new(2026, 10, 31),
      area: 10.0,
      status: "completed")
  end

  test "wizard farms index responds" do
    if rust_contract?
      response = rust_get("/api/v1/public_plans/farms?region=jp")
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get "/api/v1/public_plans/farms", params: { region: "jp" },
          headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    refute_equal 501, response.code.to_i if rust_contract?
    assert json.is_a?(Array)
  end

  test "wizard farm_sizes index responds with catalog entry" do
    if rust_contract?
      response = rust_get("/api/v1/public_plans/farm_sizes")
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get "/api/v1/public_plans/farm_sizes", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    refute_equal 501, response.code.to_i if rust_contract?
    assert json.is_a?(Array)
    home = json.find { |s| s["id"] == "home_garden" }
    assert home, "expected home_garden in farm_sizes catalog"
    assert_equal 30, home["area_sqm"]
  end

  test "wizard crops index responds for reference farm" do
    if rust_contract?
      response = rust_get("/api/v1/public_plans/crops?farm_id=#{@ref_farm.id}")
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get "/api/v1/public_plans/crops",
          params: { farm_id: @ref_farm.id },
          headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    refute_equal 501, response.code.to_i if rust_contract?
    assert json.is_a?(Array)
  end

  test "public cultivation plan data route is reachable" do
    if rust_contract?
      response = rust_get(
        "/api/v1/public_plans/cultivation_plans/#{@public_plan.id}/data"
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get "/api/v1/public_plans/cultivation_plans/#{@public_plan.id}/data",
          headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    refute_equal 501, response.code.to_i if rust_contract?
    assert json["success"]
    assert_equal @public_plan.id, json.dig("data", "id")
  end
end
