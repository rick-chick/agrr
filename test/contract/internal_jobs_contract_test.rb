# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: internal scheduler jobs on agrr-server (P6 internal_jobs done — rust contract only).
# Rails HTTP/auth/enqueue: test/controllers/api/v1/internal/jobs_controller_test.rb
class InternalJobsContractTest < ContractTestCase
  setup do
    @token = "test_scheduler_token_contract"
    ENV["SCHEDULER_AUTH_TOKEN"] = @token
  end

  teardown do
    ENV.delete("SCHEDULER_AUTH_TOKEN")
  end

  test "requires authentication token" do

    http_response = rust_post("/api/v1/internal/jobs/trigger_weather_update")
    assert_equal 401, http_response.code.to_i, http_response.body
    json = JSON.parse(http_response.body)
    assert_equal "Missing authentication token", json["error"]
  end

  test "accepts valid scheduler token" do

    create(:farm, :reference, latitude: 35.68, longitude: 139.76)

    http_response = rust_post(
      "/api/v1/internal/jobs/trigger_weather_update",
      headers: { "X-Scheduler-Token" => @token }
    )
    assert_equal 200, http_response.code.to_i, http_response.body
    json = JSON.parse(http_response.body)
    assert_equal true, json["success"]
    assert_equal "Weather update jobs enqueued", json["message"]
    assert json["timestamp"].is_a?(String)
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, json["timestamp"], "timestamp must be ISO8601")
  end

  test "accepts valid scheduler token in query params" do

    http_response = rust_post(
      "/api/v1/internal/jobs/trigger_weather_update?token=#{@token}"
    )
    assert_equal 200, http_response.code.to_i, http_response.body
    json = JSON.parse(http_response.body)
    assert_equal true, json["success"]
  end
end
