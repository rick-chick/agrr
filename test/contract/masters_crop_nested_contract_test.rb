# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: nested masters crop routes (pests / agricultural_tasks / pesticides).
class MastersCropNestedContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
    @crop = create(:crop, :user_owned, user: @user)
    @pest = create(:pest, :user_owned, user: @user)
  end

  test "get crop pests index includes associated pest" do
    skip "rust contract only" unless rust_contract?

    @crop.pests << @pest

    response = rust_get(
      "/api/v1/masters/crops/#{@crop.id}/pests",
      session_id: @session_id
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert_includes json.map { |row| row["id"] }, @pest.id
  end

  test "post crop pest association returns created shape" do
    skip "rust contract only" unless rust_contract?

    response = rust_post(
      "/api/v1/masters/crops/#{@crop.id}/pests",
      session_id: @session_id,
      body: { pest_id: @pest.id }
    )
    refute_equal 501, response.code.to_i, response.body
    assert_includes [200, 201], response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal @crop.id, json["crop_id"]
    assert_equal @pest.id, json["pest_id"]
  end

  test "get crop agricultural_tasks index returns array" do
    skip "rust contract only" unless rust_contract?

    response = rust_get(
      "/api/v1/masters/crops/#{@crop.id}/agricultural_tasks",
      session_id: @session_id
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "get crop pesticides index returns array" do
    skip "rust contract only" unless rust_contract?

    response = rust_get(
      "/api/v1/masters/crops/#{@crop.id}/pesticides",
      session_id: @session_id
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end

  test "delete crop pest association returns no content" do
    skip "rust contract only" unless rust_contract?

    @crop.pests << @pest

    response = rust_delete(
      "/api/v1/masters/crops/#{@crop.id}/pests/#{@pest.id}",
      session_id: @session_id
    )
    refute_equal 501, response.code.to_i, response.body
    assert_equal 204, response.code.to_i, response.body
  end
end
