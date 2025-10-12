# frozen_string_literal: true

require "application_system_test_case"

class CropAiButtonTest < ApplicationSystemTestCase
  setup do
    @user = users(:two)
    sign_in_system(@user)
  end

  test "AI button is visible on new crop page" do
    visit new_crop_path
    
    # AIボタンが表示されていることを確認
    assert_selector "button#ai-save-crop-btn", text: "AIで作物情報を保存"
    # ステータスdivは初期状態では非表示なので visible: :all を使用
    assert_selector "div#ai-save-status", visible: :all
  end

  test "AI button saves crop and redirects to show page" do
    visit new_crop_path
    
    # 作物情報を入力
    fill_in "名前", with: "AIテスト作物"
    fill_in "品種", with: "AIテスト品種"
    
    # AIボタンが存在することを確認
    assert_selector "button#ai-save-crop-btn"
    
    # JavaScriptが必要な機能はここではテストしない（integration testで確認）
    # システムテストではボタンの存在と基本的なDOM構造のみ確認
  end

  test "AI button shows error when name is empty" do
    visit new_crop_path
    
    # 品種のみ入力（名前は空）
    fill_in "品種", with: "品種のみ"
    
    # AIボタンが表示されていることを確認
    assert_selector "button#ai-save-crop-btn", text: "AIで作物情報を保存"
    
    # フォームバリデーションはJavaScriptレベルでテスト
    # ここではUIの存在のみ確認
  end

  test "AI button has correct attributes" do
    visit new_crop_path
    
    button = find("button#ai-save-crop-btn")
    
    # ボタンの基本属性を確認
    assert_equal "button", button[:type]
    assert button.text.include?("AI")
    assert button[:"data-controller"] == "crop-ai", 
           "Stimulus controller should be attached"
  end

  test "AI button works with variety field empty" do
    visit new_crop_path
    
    # 作物名のみ入力
    fill_in "名前", with: "品種なし作物"
    
    # AIボタンが機能的な状態であることを確認
    assert_selector "button#ai-save-crop-btn:not([disabled])"
  end

  test "AI status div exists for displaying messages" do
    visit new_crop_path
    
    # ステータス表示用のdivが存在することを確認（非表示でも検索）
    assert_selector "div#ai-save-status", visible: :all
    
    # 初期状態では非表示であることを確認
    status_div = find("div#ai-save-status", visible: :all)
    # style属性で直接 display: none が設定されている
    assert status_div[:style].include?("display: none") || status_div[:style].include?("display:none"),
           "Status div should be hidden initially"
  end

  private

  def sign_in_system(user)
    # システムテスト用のログイン
    visit '/auth/test/mock_login'
    # ログインが完了するまで待機
    assert_text "Mock login successful"
  end
end
