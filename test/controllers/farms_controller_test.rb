# frozen_string_literal: true

require 'test_helper'

class FarmsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    sign_in_as(@user)
  end

  test "新規ユーザーは4つ以上の農場を作成できる" do
    # 新規ユーザーは4つまで農場を作成できる
    4.times do |i|
      post farms_path, params: {
        farm: {
          name: "農場#{i + 1}",
          latitude: 35.6762 + i * 0.01,
          longitude: 139.6503 + i * 0.01
        }
      }
      assert_response :redirect, "Iteration #{i + 1} failed"
    end
    
    # 4個作成後の状態を確認
    assert_equal 4, @user.farms.where(is_reference: false).count
    
    # 5個目は作成できない（上限に達した）
    post farms_path, params: {
      farm: {
        name: "農場5",
        latitude: 35.6762,
        longitude: 139.6503
      }
    }
    
    assert_response :unprocessable_entity, "5th farm should fail for limit"
    assert_equal 4, @user.farms.where(is_reference: false).count
  end

  test "既存ユーザーは4つまで農場を作成できる" do
    # 既存の農場を3つ作成
    3.times do |i|
      create(:farm, user: @user, is_reference: false, name: "既存農場#{i + 1}")
    end
    
    # 4つ目の農場は作成可能
    post farms_path, params: {
      farm: {
        name: "4つ目の農場",
        latitude: 35.6762,
        longitude: 139.6503
      }
    }
    
    assert_response :redirect
    assert_equal 4, @user.farms.where(is_reference: false).count
  end

  test "既存ユーザーは5つ目の農場を作成できない" do
    # 既存の農場を4つ作成
    4.times do |i|
      create(:farm, user: @user, is_reference: false, name: "既存農場#{i + 1}")
    end
    
    # 5つ目の農場は作成不可
    post farms_path, params: {
      farm: {
        name: "5つ目の農場",
        latitude: 35.6762,
        longitude: 139.6503
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 4, @user.farms.where(is_reference: false).count
    assert_select 'div.errors', text: /農場の数が上限/
  end

  test "ユーザー農場のみでカウントされる" do
    # ユーザー農場を4つ作成
    4.times do |i|
      create(:farm, user: @user, is_reference: false, name: "既存農場#{i + 1}")
    end
    
    # 5つ目の農場は作成不可（農場は常にis_reference: falseで作成される）
    post farms_path, params: {
      farm: {
        name: "5つ目の農場",
        latitude: 35.6762,
        longitude: 139.6503
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 4, @user.farms.where(is_reference: false).count
  end

end
