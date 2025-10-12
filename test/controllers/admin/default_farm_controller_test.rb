# frozen_string_literal: true

require "test_helper"

class Admin::DefaultFarmControllerTest < ActionDispatch::IntegrationTest
  def setup
    # アノニマスユーザーを確実に作成
    User.instance_variable_set(:@anonymous_user, nil)
    @anonymous_user = User.anonymous_user
    
    # 既存のデフォルト農場を削除（テスト用）
    Farm.where(is_default: true).destroy_all
  end

  test "routes exist for default farm management" do
    # ルートが正しく設定されているか確認
    assert_recognizes(
      { controller: "admin/default_farms", action: "show" },
      { path: "/admin/default_farm", method: :get }
    )
    
    assert_recognizes(
      { controller: "admin/default_farms", action: "edit" },
      { path: "/admin/default_farm/edit", method: :get }
    )
    
    assert_recognizes(
      { controller: "admin/default_farms", action: "update" },
      { path: "/admin/default_farm", method: :patch }
    )
  end

  test "controller requires admin authentication" do
    # 未認証のアクセスはログインページにリダイレクト
    get admin_default_farm_path
    assert_redirected_to auth_login_path
  end

  test "default farm can be created and accessed" do
    # デフォルト農場を作成
    farm = Farm.find_or_create_default_farm!
    
    assert farm.persisted?
    assert farm.is_default
    assert_equal @anonymous_user.id, farm.user_id
  end
end

