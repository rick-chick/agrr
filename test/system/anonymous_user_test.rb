# frozen_string_literal: true

require "application_system_test_case"

class AnonymousUserTest < ApplicationSystemTestCase
  test "anonymous user can access top page (free plans)" do
    # トップページ（簡単作付け計画）にアクセス
    visit root_path
    
    # ログインページにリダイレクトされないことを確認
    assert_no_current_path auth_login_path
    
    # 簡単作付け計画のページが表示されることを確認
    assert_selector "h1", text: "🌱 作付け計画作成"
    assert_selector ".enhanced-selection-card"
  end
  
  test "anonymous user can start free plan creation flow" do
    # 地域のfixtureがあることを前提
    region = regions(:tokyo)
    
    # Step 1: トップページにアクセス
    visit root_path
    assert_selector "h1", text: "🌱 作付け計画作成"
    
    # Step 2: 地域を選択（リンクカードをクリック）
    click_link region.name
    
    # Step 3: 農場サイズ選択ページに遷移することを確認
    assert_selector "h1", text: "🌱 作付け計画作成"
    assert_text "農場サイズ"
  end
  
  test "current_user returns anonymous user when not logged in" do
    visit root_path
    
    # ページが正常に表示される（ログインページにリダイレクトされない）
    assert_no_current_path auth_login_path
    assert_selector "h1"
  end
  
  test "anonymous user cannot access protected pages" do
    # 農場一覧ページにアクセスを試みる
    visit farms_path
    
    # ログインページにリダイレクトされることを確認
    assert_current_path auth_login_path
    assert_text "Please log in to access this page."
  end
  
  test "anonymous user sees free plans page without login link requirement" do
    visit root_path
    
    # ページが正常に表示されることを確認
    assert_selector "h1", text: "🌱 作付け計画作成"
    
    # 地域選択カードが表示されることを確認
    assert_selector ".enhanced-selection-card"
  end
end

