# frozen_string_literal: true

require "test_helper"

class CropsFormI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @crop = crops(:tomato)
    sign_in_as(@user)
  end

  # Crops Editフォーム - 日本語ラベル
  test "should display Japanese form labels in crop edit page" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    # フォームラベル
    assert_select "label.form-label", text: /名前/
    assert_select "label.form-label", text: /品種/
    assert_select "label.form-label", text: /単位あたりの面積/
    assert_select "label.form-label", text: /面積あたりの収益/
    assert_select "label.form-label", text: /グループ/
    
    # セクションタイトル
    assert_select "h3.section-title", text: /生育ステージ/
    
    # ボタン
    assert_select "button.btn-secondary", text: /生育ステージを追加/
    assert_select "input[type='submit']"
    assert_select "a.btn", text: /キャンセル/
    
    # AIボタン
    assert_select "button#ai-save-crop-btn", text: /AIで作物情報を取得/
  end

  # Crops Editフォーム - 英語ラベル
  test "should display English form labels in crop edit page" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    # フォームラベル
    assert_select "label.form-label", text: /^Name$/
    assert_select "label.form-label", text: /Variety/
    assert_select "label.form-label", text: /Area per Unit/
    assert_select "label.form-label", text: /Revenue per Area/
    assert_select "label.form-label", text: /Groups/
    
    # セクションタイトル
    assert_select "h3.section-title", text: /Growth Stages/
    
    # ボタン
    assert_select "button.btn-secondary", text: /Add Growth Stage/
    assert_select "input[type='submit']", value: /Update Crop/
    assert_select "a.btn", text: /Cancel/
    
    # AIボタン
    assert_select "button#ai-save-crop-btn", text: /Get.*Save Crop Info with AI/
  end

  # Crops Newフォーム - 日本語ラベル
  test "should display Japanese form labels in crop new page" do
    get new_crop_path(locale: :ja)
    assert_response :success
    
    assert_select "label.form-label", text: /名前/
    assert_select "input[type='submit']", value: /作物を作成/
  end

  # Crops Newフォーム - 英語ラベル
  test "should display English form labels in crop new page" do
    get new_crop_path(locale: :us)
    assert_response :success
    
    assert_select "label.form-label", text: /Name/
    assert_select "input[type='submit']", value: /Create Crop/
  end

  # ヘルプテキスト - 日本語
  test "should display Japanese help texts in form" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select ".form-text", text: /品種名を入力してください/
    assert_select ".form-text", text: /グループをカンマ区切りで入力/
  end

  # ヘルプテキスト - 英語
  test "should display English help texts in form" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select ".form-text", text: /Enter variety name/
    assert_select ".form-text", text: /Enter crop groups separated by commas/
  end
end

