# frozen_string_literal: true

require "test_helper"

class ApiV1CropsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @admin = users(:one) # user one is admin in fixtures
    @regular_user = users(:two)
    @session_id = create_session_for(@user)
    @regular_session_id = create_session_for(@regular_user)
  end
  
  # ========================================
  # Index Tests
  # ========================================
  
  test "should get crops index with authentication" do
    get "/api/v1/crops", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
  end
  
  test "should reject crops index without authentication" do
    get "/api/v1/crops", as: :json
    
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "crops index should return user's crops and reference crops" do
    # ユーザーの作物を作成
    user_crop = Crop.create!(
      name: "User Crop",
      user: @regular_user,
      is_reference: false
    )
    
    # 参照作物を作成
    ref_crop = Crop.create!(
      name: "Reference Crop",
      user: nil,
      is_reference: true
    )
    
    # 他のユーザーの作物を作成
    Crop.create!(
      name: "Other User Crop",
      user: @admin,
      is_reference: false
    )
    
    get "/api/v1/crops", 
      headers: session_cookie_header(@regular_session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    crop_ids = json.map { |c| c["crop_id"] }
    
    # 自分の作物と参照作物のみ返されることを確認
    assert_includes crop_ids, user_crop.id
    assert_includes crop_ids, ref_crop.id
    # 他のユーザーの作物は含まれない
    assert_not crop_ids.include?(@admin.crops.where(is_reference: false).first&.id)
  end
  
  # ========================================
  # Show Tests
  # ========================================
  
  test "should show crop details" do
    crop = Crop.create!(
      name: "Test Crop",
      variety: "Test Variety",
      user: @user,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 5000.0
    )
    
    get "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal crop.id, json["crop_id"]
    assert_equal "Test Crop", json["crop_name"]
    assert_equal "Test Variety", json["variety"]
    assert_equal false, json["is_reference"]
    assert_equal 100.0, json["area_per_unit"]
    assert_equal 5000.0, json["revenue_per_area"]
    assert json["stages"].is_a?(Array)
  end
  
  test "should return 404 for non-existent crop" do
    get "/api/v1/crops/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject show without authentication" do
    crop = Crop.create!(name: "Test Crop", user: @user, is_reference: false)
    
    get "/api/v1/crops/#{crop.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Create Tests
  # ========================================
  
  test "should create crop with valid params" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops", 
        headers: session_cookie_header(@session_id),
        params: { 
          crop: {
            name: "New Crop",
            variety: "New Variety",
            area_per_unit: 150.0,
            revenue_per_area: 6000.0
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "New Crop", json["crop_name"]
    assert_equal "New Variety", json["variety"]
    assert_equal 150.0, json["area_per_unit"]
    assert_equal 6000.0, json["revenue_per_area"]
    assert_equal false, json["is_reference"]
    
    crop = Crop.find(json["crop_id"])
    assert_equal @user.id, crop.user_id
    assert_equal false, crop.is_reference
  end
  
  test "should create crop without optional params" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops", 
        headers: session_cookie_header(@session_id),
        params: { 
          crop: {
            name: "Simple Crop"
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal "Simple Crop", json["crop_name"]
  end
  
  test "admin should create reference crop" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops", 
        headers: session_cookie_header(@session_id), # admin user
        params: { 
          crop: {
            name: "Reference Crop",
            is_reference: true
          }
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal true, json["is_reference"]
    
    crop = Crop.find(json["crop_id"])
    assert_nil crop.user_id
    assert_equal true, crop.is_reference
  end
  
  test "regular user should not create reference crop" do
    post "/api/v1/crops", 
      headers: session_cookie_header(@regular_session_id),
      params: { 
        crop: {
          name: "Reference Crop",
          is_reference: true
        }
      },
      as: :json
    
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "Only admin can create reference crops", json["error"]
  end
  
  test "should reject crop creation with invalid params" do
    post "/api/v1/crops", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should reject crop creation without authentication" do
    post "/api/v1/crops", 
      params: { 
        crop: {
          name: "New Crop"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Update Tests
  # ========================================
  
  test "should update crop with valid params" do
    crop = Crop.create!(
      name: "Old Name",
      variety: "Old Variety",
      user: @user,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 5000.0
    )
    
    put "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "Updated Name",
          variety: "Updated Variety",
          area_per_unit: 200.0,
          revenue_per_area: 7000.0
        }
      },
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal "Updated Name", json["crop_name"]
    assert_equal "Updated Variety", json["variety"]
    assert_equal 200.0, json["area_per_unit"]
    assert_equal 7000.0, json["revenue_per_area"]
    
    crop.reload
    assert_equal "Updated Name", crop.name
    assert_equal "Updated Variety", crop.variety
  end
  
  test "admin should update reference flag" do
    crop = Crop.create!(
      name: "Test Crop",
      user: @user,
      is_reference: false
    )
    
    put "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id), # admin user
      params: { 
        crop: {
          is_reference: true
        }
      },
      as: :json
    
    assert_response :success
    
    crop.reload
    assert_equal true, crop.is_reference
  end
  
  test "regular user should not update reference flag" do
    crop = Crop.create!(
      name: "Test Crop",
      user: @regular_user,
      is_reference: false
    )
    
    put "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@regular_session_id),
      params: { 
        crop: {
          is_reference: true
        }
      },
      as: :json
    
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal "Only admin can change reference flag", json["error"]
  end
  
  test "should reject crop update with invalid params" do
    crop = Crop.create!(name: "Test Crop", user: @user, is_reference: false)
    
    put "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "" # 空の名前
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should return 404 when updating non-existent crop" do
    put "/api/v1/crops/999999", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unprocessable_entity
  end
  
  test "should reject crop update without authentication" do
    crop = Crop.create!(name: "Test Crop", user: @user, is_reference: false)
    
    put "/api/v1/crops/#{crop.id}", 
      params: { 
        crop: {
          name: "Updated Name"
        }
      },
      as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Destroy Tests
  # ========================================
  
  test "should destroy crop" do
    crop = Crop.create!(name: "Crop to Delete", user: @user, is_reference: false)
    
    assert_difference("Crop.count", -1) do
      delete "/api/v1/crops/#{crop.id}", 
        headers: session_cookie_header(@session_id),
        as: :json
    end
    
    assert_response :no_content
  end
  
  test "should return 404 when destroying non-existent crop" do
    delete "/api/v1/crops/999999", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
  
  test "should reject crop destroy without authentication" do
    crop = Crop.create!(name: "Test Crop", user: @user, is_reference: false)
    
    delete "/api/v1/crops/#{crop.id}", as: :json
    
    assert_response :unauthorized
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "crop response should have all required fields" do
    crop = Crop.create!(
      name: "Test Crop",
      variety: "Test Variety",
      user: @user,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 5000.0
    )
    
    get "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    json = JSON.parse(response.body)
    
    required_fields = %w[crop_id crop_name variety is_reference area_per_unit revenue_per_area stages]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "response should be valid JSON" do
    crop = Crop.create!(name: "Test Crop", user: @user, is_reference: false)
    
    get "/api/v1/crops/#{crop.id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
  
  test "response should have correct content type" do
    get "/api/v1/crops", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  # ========================================
  # CRUD Flow Test
  # ========================================
  
  test "complete crop CRUD flow" do
    # Create
    post "/api/v1/crops", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "CRUD Test Crop",
          variety: "CRUD Variety",
          area_per_unit: 100.0,
          revenue_per_area: 5000.0
        }
      },
      as: :json
    
    assert_response :created
    crop_id = JSON.parse(response.body)["crop_id"]
    
    # Show
    get "/api/v1/crops/#{crop_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    assert_equal "CRUD Test Crop", JSON.parse(response.body)["crop_name"]
    
    # Update
    put "/api/v1/crops/#{crop_id}", 
      headers: session_cookie_header(@session_id),
      params: { 
        crop: {
          name: "Updated CRUD Crop"
        }
      },
      as: :json
    
    assert_response :success
    assert_equal "Updated CRUD Crop", JSON.parse(response.body)["crop_name"]
    
    # Index (should include updated crop)
    get "/api/v1/crops", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :success
    crops = JSON.parse(response.body)
    assert crops.any? { |c| c["crop_id"] == crop_id && c["crop_name"] == "Updated CRUD Crop" }
    
    # Destroy
    delete "/api/v1/crops/#{crop_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :no_content
    
    # Verify deletion
    get "/api/v1/crops/#{crop_id}", 
      headers: session_cookie_header(@session_id),
      as: :json
    
    assert_response :not_found
  end
end

