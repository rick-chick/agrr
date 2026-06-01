# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: public plan cultivation REST mutations on agrr-server.
class PublicPlanCultivationMutationsContractTest < ContractTestCase
  setup do
    @anonymous_user = User.anonymous_user
    @farm = create(:farm, :reference,
      user: @anonymous_user,
      latitude: 35.6762,
      longitude: 139.6503,
      region: "jp")
    @plan = create(:cultivation_plan,
      farm: @farm,
      user: nil,
      plan_type: "public",
      status: "completed")
    @field = create(:cultivation_plan_field,
      cultivation_plan: @plan,
      name: "公開圃場",
      area: 100.0,
      daily_fixed_cost: 10.0)
  end

  test "add_field returns success json shape" do

    response = rust_post(
      "/api/v1/public_plans/cultivation_plans/#{@plan.id}/add_field",
      body: { field_name: "North", field_area: 50.0, daily_fixed_cost: 5.0 }
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["field"]["id"]
  end

  test "add_crop unknown crop returns not_found without creating plan crop" do

    before = CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count
    response = rust_post(
      "/api/v1/public_plans/cultivation_plans/#{@plan.id}/add_crop",
      body: { crop_id: 999_999, field_id: @field.id }
    )
    after = CultivationPlanCrop.where(cultivation_plan_id: @plan.id).count

    refute_equal 501, response.code.to_i, response.body
    assert_equal before, after
    assert_equal 404, response.code.to_i, response.body
    json = JSON.parse(response.body)
    refute json["success"]
    assert_equal "plans.errors.crop_not_found", json["message"]
  end

  test "remove_field returns success" do

    extra_field = create(:cultivation_plan_field,
      cultivation_plan: @plan,
      name: "South",
      area: 50.0,
      daily_fixed_cost: 5.0)

    response = rust_delete(
      "/api/v1/public_plans/cultivation_plans/#{@plan.id}/remove_field/#{extra_field.id}"
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["success"]
  end
end
