# frozen_string_literal: true

require "test_helper"

class ApiV1BaseIntegrationTest < ActionDispatch::IntegrationTest
  # ========================================
  # Health Check Tests
  # ========================================
  
  test "should return health check without authentication" do
    get "/api/v1/health", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal "ok", json["status"]
    assert_equal "sqlite3", json["database"]
    assert_equal "connected", json["storage"]
    assert_not_nil json["timestamp"]
    assert_equal "test", json["environment"]
    assert_equal "1.0.0", json["version"]
  end
  
  test "health check should have correct content type" do
    get "/api/v1/health", as: :json
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  test "health check should be valid JSON" do
    get "/api/v1/health", as: :json
    
    assert_response :success
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
  
  test "health check should have all required fields" do
    get "/api/v1/health", as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[status database storage timestamp environment version]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
end

