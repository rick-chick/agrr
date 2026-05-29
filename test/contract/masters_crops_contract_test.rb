# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersCropsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = Session.create_for_user(@user).session_id
    @crop = create(:crop, user: @user, name: "Contract Tomato", variety: "A")
  end

  test "crops index returns user crops" do
    if rust_contract?
      response = rust_get("/api/v1/masters/crops", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/crops", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert json.is_a?(Array)
    ids = json.map { |row| row["id"] }
    assert_includes ids, @crop.id
    row = json.find { |r| r["id"] == @crop.id }
    assert_equal @crop.name, row["name"]
    assert_equal @crop.variety, row["variety"]
  end
end
