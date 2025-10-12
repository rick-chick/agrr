# frozen_string_literal: true

require "test_helper"

class CropAiCreateTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)  # non-admin user
    sign_in_as(@user)
  end

  test "AI create endpoint exists" do
    post '/api/v1/crops/ai_create', params: { name: "ほうれん草" }, as: :json
    # created または ok（参照作物が存在する場合）
    assert_includes [200, 201], response.status
  end

  test "AI create requires crop name" do
    post '/api/v1/crops/ai_create', params: {}, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match /作物名/, json_response['error']
  end

  test "AI create fetches and saves crop info" do
    crop_name = "キャベツ"  # トマトは参照作物として存在する可能性があるため変更
    
    assert_difference('Crop.count', 1) do
      post '/api/v1/crops/ai_create',
           params: { name: crop_name },
           as: :json
    end

    assert_response :created
    
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert_equal crop_name, json_response['crop_name']
    assert json_response['crop_id'].present?
    
    # agrrから取得した情報が保存されているか確認
    assert json_response['area_per_unit'].present?
    assert json_response['revenue_per_area'].present?
    
    # データベースを確認
    crop = Crop.find(json_response['crop_id'])
    assert_equal crop_name, crop.name
    assert_equal @user.id, crop.user_id
    # agrrから取得した値が正しく保存されているか確認
    assert_not_nil crop.area_per_unit
    assert_not_nil crop.revenue_per_area
    assert crop.area_per_unit > 0, "area_per_unit should be greater than 0, got #{crop.area_per_unit}"
    assert crop.revenue_per_area > 0, "revenue_per_area should be greater than 0, got #{crop.revenue_per_area}"
    
    # 生育ステージが保存されているか確認
    assert crop.crop_stages.count > 0, "Crop stages should be saved"
    assert json_response['stages_count'].present?
    assert_equal crop.crop_stages.count, json_response['stages_count']
  end

  test "AI create with variety" do
    post '/api/v1/crops/ai_create',
         params: { name: "ナス", variety: "千両2号" },
         as: :json

    assert_response :created
    
    json_response = JSON.parse(response.body)
    crop = Crop.find(json_response['crop_id'])
    assert_equal "千両2号", crop.variety
  end

  test "AI create saves crop with user_id" do
    post '/api/v1/crops/ai_create',
         params: { name: "にんじん" },
         as: :json

    assert_response :created
    
    json_response = JSON.parse(response.body)
    crop = Crop.find(json_response['crop_id'])
    assert_equal @user.id, crop.user_id
    assert_equal false, crop.is_reference
  end

  test "AI create handles invalid crop name gracefully" do
    # agrrが存在しない作物を受け入れる場合、正常に動作する
    # agrrがエラーを返す場合、適切にエラーハンドリングされる
    post '/api/v1/crops/ai_create',
         params: { name: "存在しない作物XYZ" },
         as: :json

    # どちらの場合でも、500エラーにならないことを確認
    assert_not_equal 500, response.status
  end
end

