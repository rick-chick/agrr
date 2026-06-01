# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: masters fertilizes — parity with test/controllers/api/v1/masters/fertilizes_controller_test.rb
class MastersFertilizesContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
  end

  test "should get index" do
    create(:fertilize, :user_owned, user: @user, name: "Contract Urea")

    response = rust_get("/api/v1/masters/fertilizes", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert json.is_a?(Array)
    names = json.map { |f| f["name"] }
    assert_includes names, "Contract Urea"
  end

  test "should show fertilize" do
    fertilize = create(:fertilize, :user_owned, user: @user, name: "Show Fertilize")

    response = rust_get("/api/v1/masters/fertilizes/#{fertilize.id}", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal fertilize.id, json["id"]
    assert_equal "Show Fertilize", json["name"]
  end

  test "create returns 422 when name is missing" do
    response = rust_post(
      "/api/v1/masters/fertilizes",
      session_id: @session_id,
      body: { fertilize: { name: "", n: 1.0 } }
    )
    assert_equal 422, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert json["error"].present? || json["errors"].present?
  end

  test "should create fertilize" do
    response = rust_post(
      "/api/v1/masters/fertilizes",
      session_id: @session_id,
      body: {
        fertilize: {
          name: "Contract Created",
          n: 10.0,
          p: 5.0,
          k: 3.0
        }
      }
    )
    assert_equal 201, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal "Contract Created", json["name"]
    assert json["id"].present?
  end

  test "should update fertilize" do
    fertilize = create(:fertilize, :user_owned, user: @user, name: "Before")

    response = rust_patch(
      "/api/v1/masters/fertilizes/#{fertilize.id}",
      session_id: @session_id,
      body: { fertilize: { name: "After" } }
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    assert_equal "After", json["name"]
  end

  test "should destroy fertilize" do
    fertilize = create(:fertilize, :user_owned, user: @user, name: "To Delete")

    response = rust_delete("/api/v1/masters/fertilizes/#{fertilize.id}", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body

    assert_nil Fertilize.find_by(id: fertilize.id)
  end
end
