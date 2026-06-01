# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# P8.6: remove without agrr-r4-contract port (auth_api.rs + E2E). See P8-RAILS-SHELL-REMOVAL.md
# R4: DELETE /api/v1/auth/logout on agrr-server
class AuthLogoutContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @session_id = contract_session_id_for(@user)
  end

  test "logout clears session and returns success" do
    me_before = rust_get("/api/v1/auth/me", session_id: @session_id)
    assert_equal 200, me_before.code.to_i

    logout_resp = rust_delete("/api/v1/auth/logout", session_id: @session_id)
    assert_equal 200, logout_resp.code.to_i, logout_resp.body
    json = JSON.parse(logout_resp.body)
    assert json["success"]

    me_after = rust_get("/api/v1/auth/me", session_id: @session_id)
    assert_equal 401, me_after.code.to_i
  end
end
