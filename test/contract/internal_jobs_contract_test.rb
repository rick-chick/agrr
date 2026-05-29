# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

# R4: internal scheduler jobs — Rails ActiveJob or agrr-server in-process chain.
class InternalJobsContractTest < ContractTestCase
  setup do
    @token = "test_scheduler_token_contract"
    ENV["SCHEDULER_AUTH_TOKEN"] = @token
  end

  teardown do
    ENV.delete("SCHEDULER_AUTH_TOKEN")
  end

  test "requires authentication token" do
    if rust_contract?
      response = rust_post("/api/v1/internal/jobs/trigger_weather_update")
      assert_equal 401, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert_equal "Missing authentication token", json["error"]
    else
      post "/api/v1/internal/jobs/trigger_weather_update"
      assert_response :unauthorized
      json = JSON.parse(response.body)
      assert_equal "Missing authentication token", json["error"]
    end
  end

  test "accepts valid scheduler token" do
    if rust_contract?
      response = rust_post(
        "/api/v1/internal/jobs/trigger_weather_update",
        headers: { "X-Scheduler-Token" => @token }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert_equal true, json["success"]
    else
      assert_enqueued_with(job: UpdateReferenceWeatherDataJob) do
        assert_enqueued_with(job: UpdateUserFarmsWeatherDataJob) do
          post "/api/v1/internal/jobs/trigger_weather_update",
               headers: { "X-Scheduler-Token" => @token }
        end
      end
      assert_response :success
      json = JSON.parse(response.body)
      assert_equal true, json["success"]
    end
  end
end
