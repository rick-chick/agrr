# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4 smoke: AI routes exist on agrr-server (not 501).
# Deep agrr-daemon success paths are covered by Rails controller tests + adapter tests.
# Without USE_AGRR_DAEMON, expect 400/422/503 — never 501.
class AiApiContractTest < ContractTestCase
  test "crops ai_create is not 501" do

    response = rust_post("/api/v1/crops/ai_create", body: {})
    refute_equal 501, response.code.to_i, response.body
    assert_includes [400, 401, 422, 503], response.code.to_i, response.body
  end

  test "fertilizes ai_create is not 501" do

    response = rust_post("/api/v1/fertilizes/ai_create", body: {})
    refute_equal 501, response.code.to_i, response.body
    assert_includes [400, 401, 422, 503], response.code.to_i, response.body
  end

  test "pests ai_create is not 501" do

    response = rust_post("/api/v1/pests/ai_create", body: {})
    refute_equal 501, response.code.to_i, response.body
    assert_includes [400, 401, 422, 503], response.code.to_i, response.body
  end

  test "pests ai_update is not 501" do

    response = rust_post("/api/v1/pests/1/ai_update", body: {})
    refute_equal 501, response.code.to_i, response.body
    assert_includes [400, 401, 404, 422, 503], response.code.to_i, response.body
  end
end
