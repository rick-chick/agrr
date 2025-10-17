# frozen_string_literal: true

require "test_helper"

class CropStagesI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @crop = crops(:tomato)
    # 生育ステージを追加（テスト用）
    @crop.crop_stages.create!(
      name: "育苗期",
      order: 1
    )
    sign_in_as(@user)
  end

  # 生育ステージフィールド - 日本語ラベル
  test "should display Japanese stage field labels in crop edit page" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    # ステージフィールドのラベル
    assert_select "label.form-label", text: /^ステージ名$/
    assert_select "label.form-label", text: /^順序$/
    
    # セクションタイトル
    assert_select "h5.nested-subtitle", text: /温度要件/
    assert_select "h5.nested-subtitle", text: /熱要件（GDD）/
    assert_select "h5.nested-subtitle", text: /日照要件/
    
    # 削除ボタン
    assert_select "button.remove-crop-stage", text: /削除/
  end

  # 生育ステージフィールド - 英語ラベル
  test "should display English stage field labels in crop edit page" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    # ステージフィールドのラベル
    assert_select "label.form-label", text: /^Stage Name$/
    assert_select "label.form-label", text: /^Order$/
    
    # セクションタイトル
    assert_select "h5.nested-subtitle", text: /Temperature Requirements/
    assert_select "h5.nested-subtitle", text: /Thermal Requirements \(GDD\)/
    assert_select "h5.nested-subtitle", text: /Sunshine Requirements/
    
    # 削除ボタン
    assert_select "button.remove-crop-stage", text: /Remove/
  end

  # プレースホルダー - 日本語
  test "should display Japanese placeholders in stage fields" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select "input[placeholder*='発芽期']"
  end

  # プレースホルダー - 英語
  test "should display English placeholders in stage fields" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select "input[placeholder*='Germination']"
  end
end

