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

  test "GET /up returns service unavailable when database connection fails" do
    # データベース接続をモックしてエラーを発生させる
    ActiveRecord::Base.stub_any_instance(:execute, ->(*) { raise ActiveRecord::ConnectionNotEstablished.new("Connection failed") }) do
      get "/up"
      
      assert_response :service_unavailable
      json_response = JSON.parse(response.body)
      assert_equal "error", json_response["status"]
      assert json_response["error"].present?
      assert json_response["timestamp"].present?
    end
  end

  test "GET /up does not require authentication" do
    # 認証なしでアクセス可能であることを確認
    get "/up"
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "ok", json_response["status"]
  end

  test "GET /up returns JSON format" do
    get "/up", headers: { "Accept" => "application/json" }
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Hash)
  end

  test "GET /up handles database query errors" do
    # データベースクエリエラーをシミュレート
    ActiveRecord::Base.stub_any_instance(:execute, ->(*) { raise SQLite3::Exception.new("Database locked") }) do
      get "/up"
      
      assert_response :service_unavailable
      json_response = JSON.parse(response.body)
      assert_equal "error", json_response["status"]
      assert json_response["error"].present?
    end
  end

  test "GET /up logs errors when database check fails" do
    # エラーログが記録されることを確認
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)
    
    begin
      ActiveRecord::Base.stub_any_instance(:execute, ->(*) { raise StandardError.new("Database error") }) do
        get "/up"
      end
      
      log_output.rewind
      log_content = log_output.read
      assert log_content.include?("Health check failed"), "Expected log to include 'Health check failed'"
    ensure
      Rails.logger = original_logger
    end
  end
end

