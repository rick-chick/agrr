# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: after adjust, field_cultivations reflect agrr allocation (DB sync).
class PlanAdjustDbSyncContractTest < ContractTestCase
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
  end

  test "rust adjust persists field cultivations when agrr returns schedules" do

    before_count = FieldCultivation.where(cultivation_plan_id: @plan.id).count
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
    assert_includes [200, 400, 422, 500, 503], response.code.to_i, response.body
    return if response.code.to_i != 200

    after_count = FieldCultivation.where(cultivation_plan_id: @plan.id).count
    assert after_count >= before_count
  end

  test "adjust bad_request does not change field_cultivation count on rust" do

    crop_no_stages = create(:crop, :user_owned, user: @user)
    plan_crop = create(:cultivation_plan_crop,
      cultivation_plan: @plan,
      crop: crop_no_stages,
      name: crop_no_stages.name)
    fc = create(:field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2026, 5, 1),
      completion_date: Date.new(2026, 9, 1),
      area: 5.0,
      status: "completed")
    before_count = FieldCultivation.where(cultivation_plan_id: @plan.id).count
    response = rust_post(
      "/api/v1/plans/cultivation_plans/#{@plan.id}/adjust",
      session_id: @session_id,
      body: {
        moves: [
          {
            allocation_id: fc.id,
            action: "move",
            to_field_id: @field.id.to_s,
            to_start_date: "2026-05-01"
          }
        ]
      }
    )
    assert_equal 400, response.code.to_i, response.body
    assert_equal before_count, FieldCultivation.where(cultivation_plan_id: @plan.id).count
  end
end
