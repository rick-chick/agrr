# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersAuthContractTest < ContractTestCase
  test "rejects request without api key or session" do
    skip "rust contract only" unless rust_contract?

    response = rust_get("/api/v1/masters/crops", accept: "application/json")
    assert_equal 401, response.code.to_i
  end

  test "rejects request with invalid API key" do
    skip "rust contract only" unless rust_contract?

    response = rust_get(
      "/api/v1/masters/crops",
      headers: { "X-API-Key" => "invalid-key" },
      accept: "application/json"
    )
    assert_equal 401, response.code.to_i
  end

  test "allows request with valid API key in X-API-Key header" do
    skip "rust contract only" unless rust_contract?

    user = create(:user)
    user.generate_api_key!
    create(:crop, :user_owned, user: user)

    response = rust_get(
      "/api/v1/masters/crops",
      headers: { "X-API-Key" => user.api_key },
      accept: "application/json"
    )
    assert_equal 200, response.code.to_i, response.body
  end

  test "allows request with valid session cookie" do
    skip "rust contract only" unless rust_contract?

    user = create(:user)
    session_id = contract_session_id_for(user)
    create(:crop, :user_owned, user: user)

    response = rust_get("/api/v1/masters/crops", session_id: session_id, accept: "application/json")
    assert_equal 200, response.code.to_i, response.body
  end

  test "accepts api key from Authorization Bearer header" do
    skip "rust contract only" unless rust_contract?

    user = create(:user)
    user.generate_api_key!

    response = rust_get(
      "/api/v1/masters/crops",
      headers: { "Authorization" => "Bearer #{user.api_key}" },
      accept: "application/json"
    )
    assert_equal 200, response.code.to_i, response.body
  end

  test "accepts api key from query parameter" do
    skip "rust contract only" unless rust_contract?

    user = create(:user)
    user.generate_api_key!

    response = rust_get(
      "/api/v1/masters/crops?api_key=#{user.api_key}",
      accept: "application/json"
    )
    assert_equal 200, response.code.to_i, response.body
  end
end
