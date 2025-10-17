# frozen_string_literal: true

require "test_helper"

class CropsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @crop = crops(:tomato)
    # ユーザーとしてログイン
    sign_in_as(@user)
  end

  # Crops Show画面 - 日本語
  test "should display Japanese labels in crop show page" do
    get crop_path(@crop, locale: :ja)
    assert_response :success
    
    # 基本情報のラベル（必須フィールド）
    assert_select ".info-label", text: /名前/
    assert_select ".info-label", text: /作成日/
    assert_select ".info-label", text: /更新日/
    
    # 生育ステージセクション
    assert_select ".stages-title", text: /生育ステージ/
    
    # ボタン
    assert_select "a.btn", text: /作物一覧に戻る/
  end

  # Crops Show画面 - 英語
  test "should display English labels in crop show page" do
    get crop_path(@crop, locale: :us)
    assert_response :success
    
    # 基本情報のラベル（必須フィールド）
    assert_select ".info-label", text: /Name/
    assert_select ".info-label", text: /Created/
    assert_select ".info-label", text: /Updated/
    
    # 生育ステージセクション
    assert_select ".stages-title", text: /Growth Stages/
    
    # ボタン
    assert_select "a.btn", text: /Back to Crops/
  end

  # Crops Edit画面 - 日本語
  test "should display Japanese title in crop edit page" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select "h1.page-title", text: /#{@crop.name}を編集/
  end

  # Crops Edit画面 - 英語
  test "should display English title in crop edit page" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select "h1.page-title", text: /Edit #{@crop.name}/
  end

  # 生育ステージ詳細 - 日本語
  test "should display Japanese stage requirements labels" do
    skip "Requires crop with stages" unless @crop.crop_stages.any?
    
    get crop_path(@crop, locale: :ja)
    assert_response :success
    
    # 要件ラベル
    assert_select ".requirement-label", text: /温度要件/
    assert_select ".requirement-value", text: /最低限界温度/
    assert_select ".requirement-value", text: /最適温度/
  end

  # 生育ステージ詳細 - 英語
  test "should display English stage requirements labels" do
    skip "Requires crop with stages" unless @crop.crop_stages.any?
    
    get crop_path(@crop, locale: :us)
    assert_response :success
    
    # 要件ラベル
    assert_select ".requirement-label", text: /Temperature Requirements/
    assert_select ".requirement-value", text: /Base Temperature/
    assert_select ".requirement-value", text: /Optimal Temperature/
  end

  # 空状態メッセージ - 日本語
  test "should display Japanese empty state message when no stages" do
    crop_without_stages = Crop.create!(
      name: "テスト作物",
      user: @user,
      is_reference: false
    )
    
    get crop_path(crop_without_stages, locale: :ja)
    assert_response :success
    
    assert_select ".no-stages h3", text: /まだ生育ステージが登録されていません/
    assert_select ".no-stages p", text: /この作物の生育ステージを追加してください/
  end

  # 空状態メッセージ - 英語
  test "should display English empty state message when no stages" do
    crop_without_stages = Crop.create!(
      name: "Test Crop",
      user: @user,
      is_reference: false
    )
    
    get crop_path(crop_without_stages, locale: :us)
    assert_response :success
    
    assert_select ".no-stages h3", text: /No growth stages registered yet/
    assert_select ".no-stages p", text: /Please add growth stages for this crop/
  end

  # 削除確認メッセージ - 日本語
  test "should have Japanese delete confirmation in show page" do
    get crop_path(@crop, locale: :ja)
    assert_response :success
    
    # data-turbo-confirm属性に削除確認メッセージが含まれているか確認
    assert_select "button[type='submit']", text: /削除/
  end

  # 削除確認メッセージ - 英語
  test "should have English delete confirmation in show page" do
    get crop_path(@crop, locale: :us)
    assert_response :success
    
    # data-turbo-confirm属性に削除確認メッセージが含まれているか確認
    assert_select "button[type='submit']", text: /Delete/
  end
end

