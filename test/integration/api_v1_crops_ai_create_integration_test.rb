# frozen_string_literal: true

require "test_helper"

class ApiV1CropsAiCreateIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @session_id = create_session_for(@user)
    stub_fetch_crop_info
  end
  
  # ========================================
  # AI Create Tests (認証不要)
  # ========================================
  
  test "should create crop from AI without authentication" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops/ai_create", 
        params: { 
          name: "トマト",
          variety: "桃太郎"
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_not_nil json["crop_id"]
    assert_equal "トマト", json["crop_name"]
    assert_equal "桃太郎", json["variety"]
    assert_not_nil json["area_per_unit"]
    assert_not_nil json["revenue_per_area"]
    assert_not_nil json["stages_count"]
    assert_match(/作物「トマト」/, json["message"])
  end
  
  test "should create crop from AI with authentication" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops/ai_create", 
        headers: session_cookie_header(@session_id),
        params: { 
          name: "キャベツ",
          variety: "春キャベツ"
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_equal "キャベツ", json["crop_name"]
    assert_equal "春キャベツ", json["variety"]
    
    crop = Crop.find(json["crop_id"])
    assert_equal @user.id, crop.user_id
    assert_equal false, crop.is_reference
  end
  
  test "should create crop from AI without variety" do
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops/ai_create", 
        params: { 
          name: "レタス"
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_equal "レタス", json["crop_name"]
  end
  
  test "should update existing crop from AI" do
    # 既存の作物を作成
    existing_crop = Crop.create!(
      name: "トマト",
      user: @user,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 3000.0
    )
    
    assert_no_difference("Crop.count") do
      post "/api/v1/crops/ai_create", 
        headers: session_cookie_header(@session_id),
        params: { 
          name: "トマト",
          variety: "桃太郎"
        },
        as: :json
    end
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert_equal existing_crop.id, json["crop_id"]
    assert_match(/最新情報で更新しました/, json["message"])
    
    existing_crop.reload
    # AIから取得した値に更新されている
    assert_equal 0.5, existing_crop.area_per_unit
    assert_equal 500.0, existing_crop.revenue_per_area
  end
  
  test "should create crop stages from AI" do
    post "/api/v1/crops/ai_create", 
      headers: session_cookie_header(@session_id),
      params: { 
        name: "ニンジン"
      },
      as: :json
    
    assert_response :created
    json = JSON.parse(response.body)
    
    assert_equal true, json["success"]
    assert json["stages_count"] > 0
    
    crop = Crop.find(json["crop_id"])
    assert crop.crop_stages.count > 0
    
    stage = crop.crop_stages.first
    assert_not_nil stage.name
    assert_not_nil stage.order
    
    # Temperature requirementが存在する
    if stage.temperature_requirement
      assert_not_nil stage.temperature_requirement.base_temperature
      assert_not_nil stage.temperature_requirement.optimal_min
      assert_not_nil stage.temperature_requirement.optimal_max
    end
    
    # Sunshine requirementが存在する
    if stage.sunshine_requirement
      assert_not_nil stage.sunshine_requirement.minimum_sunshine_hours
      assert_not_nil stage.sunshine_requirement.target_sunshine_hours
    end
  end
  
  test "should reject AI create without crop name" do
    post "/api/v1/crops/ai_create", 
      params: { 
        variety: "品種のみ"
      },
      as: :json
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
    assert_match(/作物名を入力してください/, json["error"])
  end
  
  test "should reject AI create with empty crop name" do
    post "/api/v1/crops/ai_create", 
      params: { 
        name: ""
      },
      as: :json
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  test "should handle AI create with whitespace-only name" do
    post "/api/v1/crops/ai_create", 
      params: { 
        name: "   "
      },
      as: :json
    
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_not_nil json["error"]
  end
  
  # ========================================
  # agrr_crop_id Tests
  # ========================================
  
  test "should save agrr_crop_id from AI" do
    post "/api/v1/crops/ai_create", 
      headers: session_cookie_header(@session_id),
      params: { 
        name: "ダイコン"
      },
      as: :json
    
    assert_response :created
    json = JSON.parse(response.body)
    
    crop = Crop.find(json["crop_id"])
    assert_not_nil crop.agrr_crop_id
    assert_equal "ダイコン".downcase.gsub(/\s+/, '_'), crop.agrr_crop_id
  end
  
  test "should update crop by agrr_crop_id" do
    # agrr_crop_idを持つ作物を作成
    existing_crop = Crop.create!(
      name: "旧名前",
      user: @user,
      is_reference: false,
      agrr_crop_id: "たまねぎ"
    )
    
    assert_no_difference("Crop.count") do
      post "/api/v1/crops/ai_create", 
        headers: session_cookie_header(@session_id),
        params: { 
          name: "タマネギ" # agrr_crop_idが一致するので更新される
        },
        as: :json
    end
    
    assert_response :success
    json = JSON.parse(response.body)
    
    assert_equal existing_crop.id, json["crop_id"]
    assert_match(/更新しました/, json["message"])
  end
  
  # ========================================
  # Response Format Tests
  # ========================================
  
  test "AI create response should have all required fields" do
    post "/api/v1/crops/ai_create", 
      headers: session_cookie_header(@session_id),
      params: { 
        name: "ピーマン"
      },
      as: :json
    
    assert_response :created
    json = JSON.parse(response.body)
    
    required_fields = %w[success crop_id crop_name variety area_per_unit revenue_per_area stages_count message]
    required_fields.each do |field|
      assert json.key?(field), "Missing field: #{field}"
    end
  end
  
  test "AI create response should be valid JSON" do
    post "/api/v1/crops/ai_create", 
      params: { 
        name: "ブロッコリー"
      },
      as: :json
    
    assert_response :created
    assert_nothing_raised do
      JSON.parse(response.body)
    end
  end
  
  test "AI create response should have correct content type" do
    post "/api/v1/crops/ai_create", 
      params: { 
        name: "カリフラワー"
      },
      as: :json
    
    assert_response :created
    assert_equal "application/json; charset=utf-8", response.content_type
  end
  
  # ========================================
  # Edge Cases
  # ========================================
  
  test "should handle AI create with long crop name" do
    long_name = "非常に長い作物名" * 10
    
    post "/api/v1/crops/ai_create", 
      params: { 
        name: long_name
      },
      as: :json
    
    # レスポンスが返ることを確認（成功または失敗）
    assert_response :success, :created, :unprocessable_entity
  end
  
  test "should handle AI create with special characters" do
    post "/api/v1/crops/ai_create", 
      params: { 
        name: "トマト（桃太郎）"
      },
      as: :json
    
    assert_response :success, :created
  end
  
  test "should handle multiple AI creates for same crop" do
    # 1回目
    post "/api/v1/crops/ai_create", 
      headers: session_cookie_header(@session_id),
      params: { 
        name: "ナス",
        variety: "千両"
      },
      as: :json
    
    assert_response :created
    crop_id_1 = JSON.parse(response.body)["crop_id"]
    
    # 2回目（同じ作物名で更新）
    post "/api/v1/crops/ai_create", 
      headers: session_cookie_header(@session_id),
      params: { 
        name: "ナス",
        variety: "千両二号"
      },
      as: :json
    
    assert_response :success
    crop_id_2 = JSON.parse(response.body)["crop_id"]
    
    # 同じIDであることを確認（更新された）
    assert_equal crop_id_1, crop_id_2
    
    crop = Crop.find(crop_id_2)
    assert_equal "千両二号", crop.variety
  end
  
  test "should not update reference crop" do
    # 参照作物を作成
    ref_crop = Crop.create!(
      name: "参照トマト",
      user: nil,
      is_reference: true,
      agrr_crop_id: "tomato"
    )
    
    # 同じ名前で作成しても参照作物は更新されない
    assert_difference("Crop.count", 1) do
      post "/api/v1/crops/ai_create", 
        headers: session_cookie_header(@session_id),
        params: { 
          name: "参照トマト"
        },
        as: :json
    end
    
    assert_response :created
    json = JSON.parse(response.body)
    
    # 新しい作物が作成されている
    assert_not_equal ref_crop.id, json["crop_id"]
    
    new_crop = Crop.find(json["crop_id"])
    assert_equal @user.id, new_crop.user_id
    assert_equal false, new_crop.is_reference
  end
end

