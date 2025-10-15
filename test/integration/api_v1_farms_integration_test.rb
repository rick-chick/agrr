# frozen_string_literal: true

require "test_helper"

class ApiV1FarmsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session_id = create_session_for(@user)
  end
  
  # ========================================
  # Index Tests
  # ========================================
  
  test "should get farms index with authentication" do
    get "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
  
  test "should reject farms index without authentication" do
    get "/api/v1/farms", as: :json
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "farms index should return user's farms only" do
    # 他のユーザーの農場を作成
    other_user = users(:two)
    Farm.create!(name: "Other's Farm", user: other_user)
    
    get "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    # 自分の農場のみ返されることを確認
    json.each do |farm_data|
      farm = Farm.find(farm_data["id"])
      assert_equal @user.id, farm.user_id
    end
  end
  
  # ========================================
  # Show Tests
  # ========================================
  
  test "should show farm details" do
    farm = Farm.create!(
      name: "Test Farm",
      latitude: 35.6895,
      longitude: 139.6917,
      user: @user
    )
    
    get "/api/v1/farms/#{farm.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal farm.id, json["id"]
    assert_equal "Test Farm", json["name"]
    assert_equal 35.6895, json["latitude"]
    assert_equal 139.6917, json["longitude"]
    assert_not_nil json["coordinates"]
    assert_equal true, json["has_coordinates"]
    assert_not_nil json["display_name"]
    assert_not_nil json["created_at"]
    assert_not_nil json["updated_at"]
  end
  
  test "should return 404 for non-existent farm" do
    get "/api/v1/farms/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject show without authentication" do
    farm = Farm.create!(name: "Test Farm", user: @user)
    
    get "/api/v1/farms/#{farm.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Create Tests
  # ========================================
  
  test "should create farm with valid params" do
    assert_difference("Farm.count", 1) do
      post "/api/v1/farms", 
        headers: session_cookie_header(@session_id),
        params: { 
          farm: {
            name: "New Farm",
            latitude: 35.6895,
            longitude: 139.6917
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "New Farm", json["name"]
    assert_equal 35.6895, json["latitude"]
    assert_equal 139.6917, json["longitude"]
    
    farm = Farm.find(json["id"])
    assert_equal @user.id, farm.user_id
  end
  
  test "should create farm without coordinates" do
    assert_difference("Farm.count", 1) do
      post "/api/v1/farms", 
        headers: session_cookie_header(@session_id),
        params: { 
          farm: {
            name: "Farm Without Coordinates"
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "Farm Without Coordinates", json["name"]
    assert_nil json["latitude"]
    assert_nil json["longitude"]
    assert_equal false, json["has_coordinates"]
  end
  
  test "should reject farm creation with invalid params" do
    post "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject farm creation without authentication" do
    post "/api/v1/farms", 
      params: { 
        farm: {
          name: "New Farm"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Update Tests
  # ========================================
  
  test "should update farm with valid params" do
    farm = Farm.create!(
      name: "Old Name",
      latitude: 35.0,
      longitude: 139.0,
      user: @user
    )
    
    put "/api/v1/farms/#{farm.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "Updated Name",
          latitude: 36.0,
          longitude: 140.0
        }
      },
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal "Updated Name", json["name"]
    assert_equal 36.0, json["latitude"]
    assert_equal 140.0, json["longitude"]
    
    farm.reload
    assert_equal "Updated Name", farm.name
    assert_equal 36.0, farm.latitude
    assert_equal 140.0, farm.longitude
  end
  
  test "should reject farm update with invalid params" do
    farm = Farm.create!(name: "Test Farm", user: @user)
    
    put "/api/v1/farms/#{farm.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should return 404 when updating non-existent farm" do
    put "/api/v1/farms/999999", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
  end
  
  test "should reject farm update without authentication" do
    farm = Farm.create!(name: "Test Farm", user: @user)
    
    put "/api/v1/farms/#{farm.id}", 
      params: { 
        farm: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Destroy Tests
  # ========================================
  
  test "should destroy farm" do
    farm = Farm.create!(name: "Farm to Delete", user: @user)
    
    assert_difference("Farm.count", -1) do
      delete "/api/v1/farms/#{farm.id}", 
        headers: session_cookie_header(@session_id),
        as: :json
    end
    
    assert_response :no_content
  end
  
  test "should return 404 when destroying non-existent farm" do
    delete "/api/v1/farms/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
  
  test "should reject farm destroy without authentication" do
    farm = Farm.create!(name: "Test Farm", user: @user)
    
    delete "/api/v1/farms/#{farm.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "farm response should have all required fields" do
    farm = Farm.create!(
      name: "Test Farm",
      latitude: 35.6895,
      longitude: 139.6917,
      user: @user
    )
    
    get "/api/v1/farms/#{farm.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[id name latitude longitude coordinates has_coordinates display_name created_at updated_at]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "response should be valid JSON" do
    farm = Farm.create!(name: "Test Farm", user: @user)
    
    get "/api/v1/farms/#{farm.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
  
  test "response should have correct content type" do
    get "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  # ========================================
  # CRUD Flow Test
  # ========================================
  
  test "complete farm CRUD flow" do
    # Create
    post "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "CRUD Test Farm",
          latitude: 35.0,
          longitude: 139.0
        }
      },
      as: :json
    
    assert_response :created
    farm_id = JSON.parse(response.body)["id"]
    
    # Show
    get "/api/v1/farms/#{farm_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "CRUD Test Farm", JSON.parse(response.body)["name"]
    
    # Update
    put "/api/v1/farms/#{farm_id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        farm: {
          name: "Updated CRUD Farm"
        }
      },
      as: :json
    
    assert_response :success
    assert_equal "Updated CRUD Farm", JSON.parse(response.body)["name"]
    
    # Index (should include updated farm)
    get "/api/v1/farms", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    farms = JSON.parse(response.body)
    assert farms.any? { |f| f["id"] == farm_id && f["name"] == "Updated CRUD Farm" }
    
    # Destroy
    delete "/api/v1/farms/#{farm_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :no_content
    
    # Verify deletion
    get "/api/v1/farms/#{farm_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
end

