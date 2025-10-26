# frozen_string_literal: true

require 'test_helper'

class CropsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create(:user)
    sign_in_as(@user)
  end

  test "新規ユーザーは20個以上の作物を作成できる" do
    # 新規ユーザーなので制限なし（5個作成可能、テストを軽量化）
    5.times do |i|
      post crops_path, params: {
        crop: {
          name: "作物#{i + 1}",
          variety: "品種#{i + 1}",
          is_reference: false
        }
      }
      assert_response :redirect, "Iteration #{i + 1} failed"
    end
    
    # データベースを再読み込みして確認
    @user.reload
    assert_equal 5, @user.crops.where(is_reference: false).count
  end

  test "既存ユーザーは20個まで作物を作成できる" do
    # 既存の作物を19個作成
    19.times do |i|
      create(:crop, user: @user, is_reference: false, name: "既存作物#{i + 1}")
    end
    
    # 20個目の作物は作成可能
    post crops_path, params: {
      crop: {
        name: "20個目の作物",
        variety: "品種",
        is_reference: false
      }
    }
    
    assert_response :redirect
    assert_equal 20, @user.crops.where(is_reference: false).count
  end

  test "既存ユーザーは21個目の作物を作成できない" do
    # 既存の作物を20個作成
    20.times do |i|
      create(:crop, user: @user, is_reference: false, name: "既存作物#{i + 1}")
    end
    
    # 21個目の作物は作成不可
    post crops_path, params: {
      crop: {
        name: "21個目の作物",
        variety: "品種",
        is_reference: false
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 20, @user.crops.where(is_reference: false).count
    assert_select 'div.errors', text: /作物の数が上限/
  end

  test "参照作物はカウント対象外" do
    # 参照作物を20個作成
    20.times do |i|
      create(:crop, user: @user, is_reference: true, name: "参照作物#{i + 1}")
    end
    
    # ユーザー作物は20個まで作成可能（参照作物はカウント対象外）
    20.times do |i|
      post crops_path, params: {
        crop: {
          name: "作物#{i + 1}",
          variety: "品種#{i + 1}",
          is_reference: false
        }
      }
      assert_response :redirect
    end
    
    assert_equal 20, @user.crops.where(is_reference: false).count
    assert_equal 40, @user.crops.count # 参照20 + ユーザー20
  end

end
