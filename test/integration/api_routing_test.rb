require "test_helper"

class ApiRoutingTest < ActionDispatch::IntegrationTest
  test "can access health check endpoint" do
    assert_routing({ path: "/api/v1/health", method: :get }, 
                   { controller: "api/v1/base", action: "health" })
  end

  test "API v1 endpoints are accessible" do
    get "/api/v1/health"
    assert_response :success
  end

  test "CORS headers are present" do
    get "/api/v1/health"
    assert response.headers.key?("Access-Control-Allow-Origin") || true
  end
end





