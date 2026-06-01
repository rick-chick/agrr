# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: backdoor is not used by Angular; with AGRR_RUST_API / rust edge it must not reach Rails.
# POST /db/clear success is intentionally omitted — it would wipe shared contract SQLite.
class BackdoorApiContractTest < ContractTestCase
  BACKDOOR_HEADERS = { "X-Backdoor-Token" => "contract-token" }.freeze

  test "backdoor status returns daemon json when token configured" do

    response = rust_get(
      "/api/v1/backdoor/status",
      headers: BACKDOOR_HEADERS
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["daemon"].is_a?(Hash)
    assert json["timestamp"].present?
  end

  test "backdoor status requires token" do

    response = rust_get("/api/v1/backdoor/status")
    assert_equal 401, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "api.errors.backdoor.missing_token", json["error_key"]
  end

  test "backdoor status rejects invalid token" do

    response = rust_get(
      "/api/v1/backdoor/status",
      headers: { "X-Backdoor-Token" => "wrong-token" }
    )
    assert_equal 403, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "api.errors.backdoor.invalid_token", json["error_key"]
  end

  test "backdoor health returns ok when token configured" do

    response = rust_get(
      "/api/v1/backdoor/health",
      headers: BACKDOOR_HEADERS
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
  end

  test "backdoor users list returns payload when token configured" do

    response = rust_get(
      "/api/v1/backdoor/users",
      headers: BACKDOOR_HEADERS
    )
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert json["users"].is_a?(Array)
    assert json.key?("total_users")
  end

  test "backdoor clear_db rejects missing token" do

    response = rust_post("/api/v1/backdoor/db/clear", body: {})
    assert_includes [401, 403], response.code.to_i, response.body
  end
end
