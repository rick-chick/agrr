# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersCropsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @crop = create(:crop, :user_owned, user: @user, name: "Contract Tomato", variety: "A")
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

  test "should show crop with name and crop_stages in json" do
    crop = create(:crop, :user_owned, user: @user, name: "テスト作物")
    stage = create(:crop_stage, crop: crop, name: "発芽期", order: 1)

    if rust_contract?
      response = rust_get("/api/v1/masters/crops/#{crop.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      get "/api/v1/masters/crops/#{crop.id}", headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal crop.id, json["id"]
    assert_equal "テスト作物", json["name"]
    assert json["crop_stages"].present?
    assert_equal stage.id, json["crop_stages"][0]["id"]
  end

  test "should create crop" do
    if rust_contract?
      response = rust_post(
        "/api/v1/masters/crops",
        session_id: @session_id,
        body: {
          crop: {
            name: "新規作物",
            variety: "テスト品種",
            area_per_unit: 0.25,
            revenue_per_area: 5000.0
          }
        }
      )
      assert_equal 201, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      post "/api/v1/masters/crops",
           params: { crop: { name: "新規作物", variety: "テスト品種", area_per_unit: 0.25, revenue_per_area: 5000.0 } },
           headers: { "Accept" => "application/json" }
      assert_response :created
      json = JSON.parse(response.body)
    end

    assert_equal "新規作物", json["name"]
    assert_equal false, json["is_reference"]
  end

  test "should update crop" do
    crop = create(:crop, :user_owned, user: @user, name: "元の名前")

    if rust_contract?
      response = rust_patch(
        "/api/v1/masters/crops/#{crop.id}",
        session_id: @session_id,
        body: { crop: { name: "更新された名前" } }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      sign_in_as @user
      patch "/api/v1/masters/crops/#{crop.id}",
            params: { crop: { name: "更新された名前" } },
            headers: { "Accept" => "application/json" }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal "更新された名前", json["name"]
  end

  test "should destroy crop" do
    crop = create(:crop, :user_owned, user: @user)

    if rust_contract?
      response = rust_delete("/api/v1/masters/crops/#{crop.id}", session_id: @session_id)
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert json["undo"].present?
    else
      sign_in_as @user
      delete "/api/v1/masters/crops/#{crop.id}", headers: { "Accept" => "application/json" }
      assert_response :ok
    end
  end
end
