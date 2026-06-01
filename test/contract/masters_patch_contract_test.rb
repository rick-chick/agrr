# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: masters PATCH must be routed on agrr-server (not 501). Angular uses PATCH only.
class MastersPatchContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @pest = create(:pest, :user_owned, user: @user, name: "Contract Pest")
    @crop = create(:crop, :user_owned, :with_stages, user: @user)
    @crop_stage = @crop.crop_stages.first
  end

  test "patch masters pest updates name" do

    response = rust_patch(
      "/api/v1/masters/pests/#{@pest.id}",
      session_id: @session_id,
      body: { pest: { name: "Updated Pest Name" } }
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "Updated Pest Name", json["name"]
  end

  test "patch masters crop stage updates name" do

    response = rust_patch(
      "/api/v1/masters/crops/#{@crop.id}/crop_stages/#{@crop_stage.id}",
      session_id: @session_id,
      body: { crop_stage: { name: "Updated Stage", order: @crop_stage.order } }
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "Updated Stage", json["name"]
  end
end
