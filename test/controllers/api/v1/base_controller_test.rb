require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  test "health check returns JSON with expected keys" do
    get "/api/v1/health"
    assert_response :success
    assert_equal "application/json", @response.media_type

    json = JSON.parse(@response.body)
    assert_includes json.keys, "status"
    assert_includes json.keys, "database"
    assert_includes json.keys, "storage"
  end
end
