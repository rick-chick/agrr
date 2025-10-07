# frozen_string_literal: true

require 'test_helper'

class CropsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)  # 一般ユーザー
    @admin = users(:one) # 管理者ユーザー
  end

  test "index shows visible crops for signed in user" do
    sign_in_as(@user)
    get crops_path
    assert_response :success
  end

  test "create user crop" do
    sign_in_as(@user)
    assert_difference("Crop.count", +1) do
      post crops_path, params: { crop: { name: "稲", variety: "コシヒカリ" } }
    end
    assert_redirected_to crop_path(Crop.last)
    follow_redirect!
    assert_response :success
    
    crop = Crop.last
    assert_equal "稲", crop.name
    assert_equal "コシヒカリ", crop.variety
    assert_equal false, crop.is_reference
    assert_equal @user.id, crop.user_id
  end

  test "non-admin cannot create reference crop" do
    sign_in_as(@user)
    assert_no_difference("Crop.count") do
      post crops_path, params: { crop: { name: "参照稲", is_reference: true } }
    end
    assert_redirected_to crops_path
    follow_redirect!
    assert_match "参照作物は管理者のみ作成できます。", @response.body
  end

  test "admin can create reference crop" do
    sign_in_as(@admin)
    assert_difference("Crop.count", +1) do
      post crops_path, params: { crop: { name: "参照稲", is_reference: true } }
    end
    assert_redirected_to crop_path(Crop.last)
  end

  test "update reference flag requires admin" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    patch crop_path(crop), params: { crop: { is_reference: true } }
    assert_redirected_to crop_path(crop)
    follow_redirect!
    assert_match "参照フラグは管理者のみ変更できます。", @response.body
  end

  test "show crop" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    get crop_path(crop)
    assert_response :success
    assert_match crop.name, @response.body
  end

  test "show crop with stages" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    
    # Create a crop stage
    stage = crop.crop_stages.create!(
      name: "発芽期",
      order: 1
    )
    
    # Create temperature requirement separately
    stage.create_temperature_requirement!(
      base_temperature: 10,
      optimal_min: 15,
      optimal_max: 25,
      low_stress_threshold: 5,
      high_stress_threshold: 30,
      frost_threshold: 0,
      sterility_risk_threshold: 35
    )
    
    get crop_path(crop)
    assert_response :success
    assert_match "発芽期", @response.body
    assert_match "温度要件", @response.body
  end

  test "edit crop" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    get edit_crop_path(crop)
    assert_response :success
    assert_match "編集", @response.body
  end

  test "update crop" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    patch crop_path(crop), params: { crop: { name: "米", variety: "コシヒカリ" } }
    assert_redirected_to crop_path(crop)
    crop.reload
    assert_equal "米", crop.name
    assert_equal "コシヒカリ", crop.variety
  end

  test "delete crop" do
    sign_in_as(@user)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    assert_difference("Crop.count", -1) do
      delete crop_path(crop)
    end
    assert_redirected_to crops_path
  end

  test "new crop page" do
    sign_in_as(@user)
    get new_crop_path
    assert_response :success
    assert_match "新しい作物を追加", @response.body
  end

  test "crop validation - name required" do
    sign_in_as(@user)
    assert_no_difference("Crop.count") do
      post crops_path, params: { crop: { name: "", variety: "コシヒカリ" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin can update reference flag" do
    sign_in_as(@admin)
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    patch crop_path(crop), params: { crop: { is_reference: true } }
    assert_redirected_to crop_path(crop)
    crop.reload
    assert_equal true, crop.is_reference
  end

  test "unauthorized access to crops" do
    get crops_path
    assert_redirected_to auth_login_path
  end

  test "unauthorized access to specific crop" do
    crop = Crop.create!(name: "稲", user_id: @user.id, is_reference: false)
    get crop_path(crop)
    assert_redirected_to auth_login_path
  end
end


