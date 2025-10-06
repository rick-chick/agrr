# frozen_string_literal: true

require 'test_helper'

class CropsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @admin = users(:admin)
  end

  test "index shows visible crops for signed in user" do
    sign_in_as(@user)
    get crops_path
    assert_response :success
  end

  test "create user crop" do
    sign_in_as(@user)
    assert_difference("Crop.count", +1) do
      post crops_path, params: { crop: { name: "稲", variety: "コシヒカリ", is_reference: false } }
    end
    follow_redirect!
    assert_response :success
    assert_match "作物が正常に作成されました。", @response.body
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
    assert_match "作物詳細", @response.body
  end
end


