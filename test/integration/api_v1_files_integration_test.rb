# frozen_string_literal: true

require "test_helper"

class ApiV1FilesIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session_id = create_session_for(@user)
  end
  
  # ========================================
  # Index Tests
  # ========================================
  
  test "should get files index with authentication" do
    get "/api/v1/files", headers: session_cookie_header(@session_id), as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
  
  test "should reject files index without authentication" do
    get "/api/v1/files", as: :json
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  # ========================================
  # Create Tests
  # ========================================
  
  test "should create file with valid upload" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    
    post "/api/v1/files", 
      headers: session_cookie_header(@session_id),
      params: { file: file },
      as: :json
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_not_nil json["id"]
    assert_equal "test.txt", json["filename"]
    assert_equal "text/plain", json["content_type"]
    assert_not_nil json["byte_size"]
    assert_not_nil json["created_at"]
    assert_not_nil json["url"]
  end
  
  test "should reject file creation without file" do
    post "/api/v1/files", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "No file provided", json["error"]
  end
  
  test "should reject file creation without authentication" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    
    post "/api/v1/files", 
      params: { file: file },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Show Tests
  # ========================================
  
  test "should show file details" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: "test.txt",
      content_type: "text/plain"
    )
    
    get "/api/v1/files/#{blob.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal blob.id, json["id"]
    assert_equal "test.txt", json["filename"]
    assert_equal "text/plain", json["content_type"]
  end
  
  test "should return 404 for non-existent file" do
    get "/api/v1/files/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "File not found", json["error"]
  end
  
  test "should reject show without authentication" do
    get "/api/v1/files/1", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Destroy Tests
  # ========================================
  
  test "should delete file" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: "test_delete.txt",
      content_type: "text/plain"
    )
    
    assert_difference("ActiveStorage::Blob.count", -1) do
      delete "/api/v1/files/#{blob.id}", 
        headers: session_cookie_header(@session_id),
        as: :json
    end
    
    assert_response :no_content
  end
  
  test "should return 404 when deleting non-existent file" do
    delete "/api/v1/files/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
  
  test "should reject delete without authentication" do
    delete "/api/v1/files/1", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "file response should have all required fields" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: "test.txt",
      content_type: "text/plain"
    )
    
    get "/api/v1/files/#{blob.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[id filename content_type byte_size created_at url]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "files index should return array" do
    get "/api/v1/files", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
end

