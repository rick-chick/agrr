# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersFarmsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = Session.create_for_user(@user).session_id
    @farm = create(:farm, user: @user, name: "Contract Farm", region: "jp")
  end

  test "farms index returns user farms" do
    if rust_contract?
      response = rust_get("/api/v1/masters/farms", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/farms", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert json.is_a?(Array)
    ids = json.map { |row| row["id"] }
    assert_includes ids, @farm.id
    row = json.find { |r| r["id"] == @farm.id }
    assert_equal @farm.name, row["name"]
    assert_equal @farm.region, row["region"]
  end

  test "farms show returns farm with fields array" do
    field = create(:field, farm: @farm, user: @user, name: "North")

    if rust_contract?
      response = rust_get("/api/v1/masters/farms/#{@farm.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/farms/#{@farm.id}", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(body)
    end

    assert_equal @farm.id, json["id"]
    assert_equal @farm.name, json["name"]
    assert json["fields"].is_a?(Array)
    field_ids = json["fields"].map { |f| f["id"] }
    assert_includes field_ids, field.id
  end
end
