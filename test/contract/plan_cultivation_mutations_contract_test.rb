# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"
require_relative "support/gcs_weather_fixture"

# R4: private plan cultivation REST mutations (Wave B) — rust edge when CONTRACT_RUNTIME=rust.
class PlanCultivationMutationsContractTest < ContractTestCase
  include GcsWeatherFixture

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @weather_location = create(:weather_location)
    @farm.update!(weather_location: @weather_location)
    @plan = create(:cultivation_plan, :annual_planning,
      farm: @farm,
      user: @user,
      plan_type: "private",
      status: "completed")
    @field = create(:cultivation_plan_field,
      cultivation_plan: @plan,
      name: "Field A",
      area: 100.0,
      daily_fixed_cost: 10.0)
    @crop = create(:crop, :user_owned, :with_stages, user: @user)
    @plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: @plan,
      crop: @crop,
      name: @crop.name,
      variety: @crop.variety)
    @field_cultivation = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2026, 4, 1),
      completion_date: Date.new(2026, 10, 31),
      area: 10.0,
      status: "completed")
    @session_id = contract_session_id_for(@user)
    seed_rust_gcs_weather_fixture!(
      weather_location_id: @weather_location.id,
      dates: (Date.new(2026, 4, 1)..Date.new(2026, 4, 14)).to_a
    )
  end

  test "add_field returns success json shape" do

    response = rust_post(
      "/api/v1/plans/cultivation_plans/#{@plan.id}/add_field",
      session_id: @session_id,
      body: { field_name: "North", field_area: 50.0, daily_fixed_cost: 5.0 }
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["field"]["id"]
  end

  test "adjust without growth stages returns bad_request" do
    crop_no_stages = create(:crop, :user_owned, user: @user)
    plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: @plan,
      crop: crop_no_stages,
      name: crop_no_stages.name)
    create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2026, 5, 1),
      completion_date: Date.new(2026, 9, 1),
      area: 5.0,
      status: "completed")

    response = rust_post(
      "/api/v1/plans/cultivation_plans/#{@plan.id}/adjust",
      session_id: @session_id,
      body: {
        moves: [
          {
            allocation_id: @field_cultivation.id,
            action: "move",
            to_field_id: @field.id.to_s,
            to_start_date: "2026-05-01"
          }
        ]
      }
    )
    assert_equal 400, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "add_crop unknown crop returns not_found without creating plan crop" do

    before = CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count
    response = rust_post(
      "/api/v1/plans/cultivation_plans/#{@plan.id}/add_crop",
      session_id: @session_id,
      body: { crop_id: 999_999, field_id: @field.id }
    )
    after = CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count

    assert_equal before, after
    assert_equal 404, response.code.to_i, response.body
    json = JSON.parse(response.body)
    refute json["success"]
    assert_equal "plans.errors.crop_not_found", json["message"]
  end

  test "climate_data route is not 501 on rust" do

    response = rust_get(
      "/api/v1/plans/field_cultivations/#{@field_cultivation.id}/climate_data",
      session_id: @session_id
    )
    refute_equal 501, response.code.to_i
    assert_includes [200, 404, 422, 503], response.code.to_i

    return unless response.code.to_i == 200
    return unless ENV["WEATHER_DATA_STORAGE"] == "gcs"

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    weather_payload = json["weather_data"]
    assert weather_payload.is_a?(Hash), "expected weather_data object"
    data = weather_payload["data"]
    assert data.is_a?(Array) && data.any?,
           "expected non-empty observed weather from GCS bulk (fixture under #{gcs_fixture_path(@weather_location.id, 2026)})"
    assert_empty WeatherData.where(weather_location_id: @weather_location.id),
                 "climate bulk path must not rely on SQLite weather_data rows"
  end
end
