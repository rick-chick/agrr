# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class ApiV1HealthContractTest < ContractTestCase
  test "GET /api/v1/health returns ok payload" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/health")
    assert_equal 200, response.code.to_i, response.body
    json = JSON.parse(response.body)
    assert_equal "ok", json["status"]
    assert_equal "sqlite3", json["database"]
    assert json["timestamp"].present?
    assert json["version"].present?
  end
end
