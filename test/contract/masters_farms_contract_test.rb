# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersFarmsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @farm = create(:farm, :user_owned, user: @user, name: "Contract Farm", region: "jp")
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

  test "should create farm" do
    if rust_contract?
      response = rust_post(
        "/api/v1/masters/farms",
        session_id: @session_id,
        body: {
          farm: {
            name: "新規農場",
            latitude: 35.6812,
            longitude: 139.7671,
            region: "jp"
          }
        }
      )
      assert_equal 201, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      post "/api/v1/masters/farms",
           params: {
             farm: { name: "新規農場", latitude: 35.6812, longitude: 139.7671, region: "jp" }
           },
           headers: { "Accept" => "application/json" }
      assert_response :created
      json = JSON.parse(response.body)
    end

    assert_equal "新規農場", json["name"]
    assert_equal false, json["is_reference"]
  end

  test "should update farm" do
    if rust_contract?
      response = rust_patch(
        "/api/v1/masters/farms/#{@farm.id}",
        session_id: @session_id,
        body: { farm: { name: "更新された農場" } }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      patch "/api/v1/masters/farms/#{@farm.id}",
            params: { farm: { name: "更新された農場" } },
            headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal "更新された農場", json["name"]
  end

  test "should destroy farm" do
    farm = create(:farm, :user_owned, user: @user)

    if rust_contract?
      response = rust_delete("/api/v1/masters/farms/#{farm.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert json["undo"].present? || json.key?("undo_token")
    else
      sign_in_as @user
      delete "/api/v1/masters/farms/#{farm.id}", headers: { "Accept" => "application/json" }
      assert_response :ok
    end
  end
end
