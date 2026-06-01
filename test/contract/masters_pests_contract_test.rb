# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: masters pests JSON shape must match Rails (flat Pest on show/index/create).
class MastersPestsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
  end

  test "post create and get show return flat pest with name" do

    create = rust_post(
      "/api/v1/masters/pests",
      session_id: @session_id,
      body: {
        pest: {
          name: "Contract New Pest",
          name_scientific: "Pestus contractus",
          family: "Test family"
        }
      }
    )
    assert_equal 201, create.code.to_i, create.body
    created = JSON.parse(create.body)
    assert_equal "Contract New Pest", created["name"]
    assert created["id"].present?
    refute created.key?("pest"), "create must not nest under pest"

    show = rust_get(
      "/api/v1/masters/pests/#{created['id']}",
      session_id: @session_id
    )
    assert_equal 200, show.code.to_i, show.body
    detail = JSON.parse(show.body)
    assert_equal created["id"], detail["id"]
    assert_equal "Contract New Pest", detail["name"]
    assert_equal "Pestus contractus", detail["name_scientific"]
    assert_equal "Test family", detail["family"]
    refute detail.key?("pest"), "show must be flat Pest JSON for Angular"
  end

  test "index lists created pest name at top level" do

    pest = create(:pest, :user_owned, user: @user, name: "Contract List Pest")

    response = rust_get("/api/v1/masters/pests", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    rows = JSON.parse(response.body)
    assert rows.is_a?(Array)
    row = rows.find { |r| r["id"] == pest.id }
    assert row, "expected pest in index"
    assert_equal "Contract List Pest", row["name"]
    refute row.key?("record"), "index rows must be flat pest entities"
  end
end
