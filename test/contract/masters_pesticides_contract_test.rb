# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersPesticidesContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @crop = create(:crop, :user_owned, user: @user)
    @pest = create(:pest, :user_owned, user: @user, name: "Contract Pest")
  end

  test "should get index" do
    create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "Index Pesticide")

    response = rust_get("/api/v1/masters/pesticides", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert json.is_a?(Array)
    assert json.any? { |p| p["name"] == "Index Pesticide" }
  end

  test "should show pesticide" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "Show Pesticide")

    response = rust_get("/api/v1/masters/pesticides/#{pesticide.id}", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal pesticide.id, json["id"]
    assert_equal "Show Pesticide", json["name"]
  end

  test "should create pesticide" do
    response = rust_post(
      "/api/v1/masters/pesticides",
      session_id: @session_id,
      body: {
        pesticide: {
          name: "Contract Pesticide",
          crop_id: @crop.id,
          pest_id: @pest.id
        }
      }
    )
    assert_equal 201, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal "Contract Pesticide", json["name"]
    assert json["id"].present?
  end

  test "should update pesticide" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "Before")

    response = rust_patch(
      "/api/v1/masters/pesticides/#{pesticide.id}",
      session_id: @session_id,
      body: { pesticide: { name: "After" } }
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal "After", json["name"]
  end

  test "should destroy pesticide" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "Delete Me")

    response = rust_delete("/api/v1/masters/pesticides/#{pesticide.id}", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body

    assert_nil Pesticide.find_by(id: pesticide.id)
  end
end
