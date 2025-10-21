# frozen_string_literal: true

require 'test_helper'

class CropsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:two)  # 一般ユーザー
    @admin = users(:one) # 管理者ユーザー
  end

  test "complete crop management flow" do
    sign_in_as(@user)
    
    # Visit crops index
    get crops_path
    assert_response :success
    assert_match "作物一覧", @response.body
    
    # Create new crop
    get new_crop_path
    assert_response :success
    assert_match "新しい作物を追加", @response.body
    
    # Submit new crop
    post crops_path, params: {
      crop: {
        name: "テスト作物",
        variety: "テスト品種"
      }
    }
    
    assert_redirected_to crop_path(Crop.last)
    follow_redirect!
    assert_response :success
    assert_match "テスト作物", @response.body
    assert_match "テスト品種", @response.body
    
    # Edit crop
    get edit_crop_path(Crop.last)
    assert_response :success
    assert_match "テスト作物を編集", @response.body
    
    # Update crop
    patch crop_path(Crop.last), params: {
      crop: {
        name: "更新された作物",
        variety: "更新された品種"
      }
    }
    
    assert_redirected_to crop_path(Crop.last)
    follow_redirect!
    assert_response :success
    assert_match "更新された作物", @response.body
    assert_match "更新された品種", @response.body
    
    # Delete crop
    assert_difference("Crop.count", -1) do
      delete crop_path(Crop.last)
    end
    assert_redirected_to crops_path
  end

  test "crop with stages display" do
    sign_in_as(@user)
    
    # Create crop with stages
    crop = Crop.create!(
      name: "複雑な作物",
      user_id: @user.id,
      is_reference: false
    )
    
    # Add stages with requirements
    stage1 = crop.crop_stages.create!(
      name: "発芽期",
      order: 1
    )
    stage1.create_temperature_requirement!(
      base_temperature: 10,
      optimal_min: 15,
      optimal_max: 25,
      low_stress_threshold: 5,
      high_stress_threshold: 30,
      frost_threshold: 0,
      sterility_risk_threshold: 35
    )
    
    stage2 = crop.crop_stages.create!(
      name: "開花期",
      order: 2
    )
    stage2.create_sunshine_requirement!(
      minimum_sunshine_hours: 8,
      target_sunshine_hours: 12
    )
    
    stage3 = crop.crop_stages.create!(
      name: "成熟期",
      order: 3
    )
    
    # View crop details
    get crop_path(crop)
    assert_response :success
    
    # Check stage information is displayed
    assert_match "発芽期", @response.body
    assert_match "開花期", @response.body
    assert_match "成熟期", @response.body
    assert_match "温度要件", @response.body
    assert_match "日照要件", @response.body
  end

  test "admin crop management" do
    sign_in_as(@admin)
    
    # Admin can create reference crops
    post crops_path, params: {
      crop: {
        name: "参照作物",
        variety: "参照品種",
        is_reference: true
      }
    }
    
    assert_redirected_to crop_path(Crop.last)
    crop = Crop.last
    assert_equal true, crop.is_reference
    
    # Admin can update reference flag
    patch crop_path(crop), params: {
      crop: {
        is_reference: false
      }
    }
    
    assert_redirected_to crop_path(crop)
    crop.reload
    assert_equal false, crop.is_reference
  end

  test "error handling and validation" do
    sign_in_as(@user)
    
    # Try to create crop without name
    post crops_path, params: {
      crop: {
        name: "",
        variety: "テスト品種"
      }
    }
    
    assert_response :unprocessable_entity
    # Check for Japanese validation message (日本語のバリデーションメッセージを確認)
    assert_match(/名前.*入力してください/, @response.body)
    
    # Try to create reference crop as non-admin
    post crops_path, params: {
      crop: {
        name: "参照作物",
        is_reference: true
      }
    }
    
    assert_redirected_to crops_path
    follow_redirect!
    assert_match "参照作物は管理者のみ作成できます", @response.body
    
    # Try to access non-existent crop
    get crop_path(99999)
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "navigation and breadcrumbs" do
    sign_in_as(@user)
    
    # Check navigation links in header
    get crops_path
    assert_match "AGRR", @response.body  # Brand name instead of "ホーム"
    assert_match "農場", @response.body
    assert_match "作物", @response.body
    
    # Check back navigation in crop detail
    crop = Crop.create!(
      name: "ナビゲーションテスト",
      user_id: @user.id,
      is_reference: false
    )
    
    get crop_path(crop)
    assert_match "作物一覧に戻る", @response.body
    assert_match "編集", @response.body
  end
end
