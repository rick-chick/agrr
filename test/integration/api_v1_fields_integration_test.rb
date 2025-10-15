# frozen_string_literal: true

require "test_helper"

class ApiV1FieldsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session_id = create_session_for(@user)
    @farm = Farm.create!(name: "Test Farm", user: @user)
  end
  
  # ========================================
  # Index Tests
  # ========================================
  
  test "should get fields index with authentication" do
    get "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
  
  test "should reject fields index without authentication" do
    get "/api/v1/farms/#{@farm.id}/fields", as: :json
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should return 404 for non-existent farm" do
    get "/api/v1/farms/999999/fields", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Farm not found", json["error"]
  end
  
  test "fields index should return farm's fields only" do
    # この農場に圃場を作成
    field1 = Field.create!(name: "Field 1", farm: @farm, user: @user)
    field2 = Field.create!(name: "Field 2", farm: @farm, user: @user)
    
    # 別の農場に圃場を作成
    other_farm = Farm.create!(name: "Other Farm", user: @user)
    Field.create!(name: "Other Field", farm: other_farm, user: @user)
    
    get "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    # この農場の圃場のみ返されることを確認
    assert_equal 2, json.length
    field_ids = json.map { |f| f["id"] }
    assert_includes field_ids, field1.id
    assert_includes field_ids, field2.id
  end
  
  # ========================================
  # Show Tests
  # ========================================
  
  test "should show field details" do
    field = Field.create!(
      name: "Test Field",
      description: "Test Description",
      farm: @farm,
      user: @user
    )
    
    get "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal field.id, json["id"]
    assert_equal @farm.id, json["farm_id"]
    assert_equal "Test Field", json["name"]
    assert_equal "Test Description", json["description"]
    assert_not_nil json["display_name"]
    assert_not_nil json["created_at"]
    assert_not_nil json["updated_at"]
  end
  
  test "should return 404 for non-existent field" do
    get "/api/v1/farms/#{@farm.id}/fields/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject show without authentication" do
    field = Field.create!(name: "Test Field", farm: @farm, user: @user)
    
    get "/api/v1/farms/#{@farm.id}/fields/#{field.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Create Tests
  # ========================================
  
  test "should create field with valid params" do
    assert_difference("Field.count", 1) do
      post "/api/v1/farms/#{@farm.id}/fields", 
        headers: session_cookie_header(@session_id),
        params: { 
          field: {
            name: "New Field",
            description: "New Description"
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "New Field", json["name"]
    assert_equal "New Description", json["description"]
    assert_equal @farm.id, json["farm_id"]
    
    field = Field.find(json["id"])
    assert_equal @user.id, field.user_id
    assert_equal @farm.id, field.farm_id
  end
  
  test "should create field without description" do
    assert_difference("Field.count", 1) do
      post "/api/v1/farms/#{@farm.id}/fields", 
        headers: session_cookie_header(@session_id),
        params: { 
          field: {
            name: "Field Without Description"
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "Field Without Description", json["name"]
    assert_nil json["description"]
  end
  
  test "should reject field creation with invalid params" do
    post "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject field creation for non-existent farm" do
    post "/api/v1/farms/999999/fields", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "New Field"
        }
      },
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Farm not found", json["error"]
  end
  
  test "should reject field creation without authentication" do
    post "/api/v1/farms/#{@farm.id}/fields", 
      params: { 
        field: {
          name: "New Field"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Update Tests
  # ========================================
  
  test "should update field with valid params" do
    field = Field.create!(
      name: "Old Name",
      description: "Old Description",
      farm: @farm,
      user: @user
    )
    
    put "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "Updated Name",
          description: "Updated Description"
        }
      },
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal "Updated Name", json["name"]
    assert_equal "Updated Description", json["description"]
    
    field.reload
    assert_equal "Updated Name", field.name
    assert_equal "Updated Description", field.description
  end
  
  test "should reject field update with invalid params" do
    field = Field.create!(name: "Test Field", farm: @farm, user: @user)
    
    put "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should return 404 when updating non-existent field" do
    put "/api/v1/farms/#{@farm.id}/fields/999999", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
  end
  
  test "should reject field update without authentication" do
    field = Field.create!(name: "Test Field", farm: @farm, user: @user)
    
    put "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      params: { 
        field: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Destroy Tests
  # ========================================
  
  test "should destroy field" do
    field = Field.create!(name: "Field to Delete", farm: @farm, user: @user)
    
    assert_difference("Field.count", -1) do
      delete "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
        headers: session_cookie_header(@session_id),
        as: :json
    end
    
    assert_response :no_content
  end
  
  test "should return 404 when destroying non-existent field" do
    delete "/api/v1/farms/#{@farm.id}/fields/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
  
  test "should reject field destroy without authentication" do
    field = Field.create!(name: "Test Field", farm: @farm, user: @user)
    
    delete "/api/v1/farms/#{@farm.id}/fields/#{field.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "field response should have all required fields" do
    field = Field.create!(
      name: "Test Field",
      description: "Test Description",
      farm: @farm,
      user: @user
    )
    
    get "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[id farm_id name description display_name created_at updated_at]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "response should be valid JSON" do
    field = Field.create!(name: "Test Field", farm: @farm, user: @user)
    
    get "/api/v1/farms/#{@farm.id}/fields/#{field.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
  
  test "response should have correct content type" do
    get "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  # ========================================
  # CRUD Flow Test
  # ========================================
  
  test "complete field CRUD flow" do
    # Create
    post "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "CRUD Test Field",
          description: "CRUD Description"
        }
      },
      as: :json
    
    assert_response :created
    field_id = JSON.parse(response.body)["id"]
    
    # Show
    get "/api/v1/farms/#{@farm.id}/fields/#{field_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "CRUD Test Field", JSON.parse(response.body)["name"]
    
    # Update
    put "/api/v1/farms/#{@farm.id}/fields/#{field_id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        field: {
          name: "Updated CRUD Field"
        }
      },
      as: :json
    
    assert_response :success
    assert_equal "Updated CRUD Field", JSON.parse(response.body)["name"]
    
    # Index (should include updated field)
    get "/api/v1/farms/#{@farm.id}/fields", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    fields = JSON.parse(response.body)
    assert fields.any? { |f| f["id"] == field_id && f["name"] == "Updated CRUD Field" }
    
    # Destroy
    delete "/api/v1/farms/#{@farm.id}/fields/#{field_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :no_content
    
    # Verify deletion
    get "/api/v1/farms/#{@farm.id}/fields/#{field_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
end

