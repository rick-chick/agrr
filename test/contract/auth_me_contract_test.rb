# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: mirrors Api::V1::AuthController#me JSON shape
class AuthMeContractTest < ContractTestCase
  setup do
    @user = create(:user, name: "Contract User", email: "contract@example.com")
    @session_id = Session.create_for_user(@user).session_id
  end

  test "me returns current user" do
    response = rust_get("/api/v1/auth/me", session_id: @session_id)
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)

    user = json["user"]
    assert_equal @user.id, user["id"]
    assert_equal @user.name, user["name"]
    assert_equal @user.email, user["email"]
    assert_equal @user.admin?, user["admin"]
    if @user.api_key.nil?
      assert_nil user["api_key"]
    else
      assert_equal @user.api_key, user["api_key"]
    end
  end

  test "me returns unauthorized when not authenticated" do
    response = rust_get("/api/v1/auth/me")
    assert_equal 401, response.code.to_i
  end
end
