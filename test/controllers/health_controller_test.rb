# frozen_string_literal: true

require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET /up returns ok status when database is available" do
    get "/up"

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "ok", json_response["status"]
    assert_equal "primary", json_response["database"]
    assert json_response["timestamp"].present?
  end

  test "GET /up returns JSON format" do
    get "/up", headers: { "Accept" => "application/json" }

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Hash)
  end
end
