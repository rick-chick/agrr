# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: plan read after create (optimization chain runs in-process on agrr-server).
class PrivatePlanOptimizationJobChainContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @weather_location = WeatherLocation.find_or_create_by!(latitude: 36.0, longitude: 140.0) do |wl|
      wl.elevation = 50.0
      wl.timezone = "Asia/Tokyo"
    end
    @farm = create(:farm, user: @user, latitude: 36.0, longitude: 140.0, region: "jp", weather_location: @weather_location)
    @plan = create(:cultivation_plan, farm: @farm, user: @user, plan_type: "private")
    crop = create(:crop, user: @user, is_reference: false, region: "jp", revenue_per_area: 1000.0)
    create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    create(:crop_task_schedule_blueprint, crop: crop)
    @session_id = contract_session_id_for(@user)
  end

  test "plan show is available for optimization chain context" do

    response = rust_get("/api/v1/plans/#{@plan.id}", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["id"].present?
  end
end
