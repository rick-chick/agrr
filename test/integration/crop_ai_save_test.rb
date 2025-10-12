# frozen_string_literal: true

require "test_helper"

class CropAiSaveTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)  # non-admin user
    sign_in_as(@user)
    # AGRRコマンドをモック化して高速化
    stub_all_agrr_commands
  end

  test "new crop page has AI save button" do
    get new_crop_path
    assert_response :success
    
    assert_select 'button#ai-save-crop-btn', text: /AIで作物情報を取得・保存/
    assert_select 'div#ai-save-status'
  end

  test "AI save creates crop via API" do
    crop_params = {
      crop: {
        name: "キャベツ",
        variety: "春系",
        is_reference: false
      }
    }

    assert_difference('Crop.count', 1) do
      post api_v1_crops_path, 
           params: crop_params,
           as: :json
    end

    assert_response :created
    
    json_response = JSON.parse(response.body)
    assert_equal "キャベツ", json_response['crop_name']
    assert_equal "春系", json_response['variety']
    assert_equal false, json_response['is_reference']
    assert json_response['crop_id'].present?
  end

  test "AI save requires crop name" do
    crop_params = {
      crop: {
        name: "",
        variety: "春系",
        is_reference: false
      }
    }

    assert_no_difference('Crop.count') do
      post api_v1_crops_path, 
           params: crop_params,
           as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response['error'].present?
  end

  test "AI save creates crop with user_id" do
    crop_params = {
      crop: {
        name: "レタス",
        variety: "サニーレタス",
        is_reference: false
      }
    }

    post api_v1_crops_path, 
         params: crop_params,
         as: :json

    assert_response :created
    
    json_response = JSON.parse(response.body)
    created_crop_id = json_response['crop_id']
    
    created_crop = Crop.find(created_crop_id)
    assert_not_nil created_crop
    assert_equal @user.id, created_crop.user_id
    assert_equal false, created_crop.is_reference
  end

  test "non-admin cannot create reference crop via AI" do
    crop_params = {
      crop: {
        name: "トマト参照",
        variety: "大玉",
        is_reference: true
      }
    }

    post api_v1_crops_path, 
         params: crop_params,
         as: :json

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_match /admin/i, json_response['error']
  end

  test "should reject invalid area_per_unit" do
    crop_params = {
      crop: {
        name: "トマト",
        variety: "大玉",
        area_per_unit: -100.0,
        is_reference: false
      }
    }

    post api_v1_crops_path, 
         params: crop_params,
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response['error'].present?
  end

  test "should reject invalid revenue_per_area" do
    crop_params = {
      crop: {
        name: "トマト",
        variety: "大玉",
        revenue_per_area: -1000.0,
        is_reference: false
      }
    }

    post api_v1_crops_path, 
         params: crop_params,
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response['error'].present?
  end

end
