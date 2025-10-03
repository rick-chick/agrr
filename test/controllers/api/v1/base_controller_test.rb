require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  test "health check endpoint returns success" do
    get "/api/v1/health"
    assert_response :success
    assert_equal "application/json", @response.media_type
  end

  test "health check includes database connection status" do
    get "/api/v1/health"
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    assert_includes json_response.keys, "database"
  end

  test "health check includes storage status" do
    get "/api/v1/health"
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    assert_includes json_response.keys, "storage"
  end
end
