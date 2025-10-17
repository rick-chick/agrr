# frozen_string_literal: true

require "test_helper"

class CropRequirementsI18nTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @crop = crops(:tomato)
    # 生育ステージと各要件を追加
    @stage = @crop.crop_stages.create!(
      name: "育苗期",
      order: 1
    )
    # 温度要件を追加
    @stage.build_temperature_requirement(
      base_temperature: 5.0,
      optimal_min: 15.0,
      optimal_max: 25.0
    )
    # 熱要件を追加
    @stage.build_thermal_requirement(
      required_gdd: 800.0
    )
    # 日照要件を追加
    @stage.build_sunshine_requirement(
      minimum_sunshine_hours: 4.0,
      target_sunshine_hours: 8.0
    )
    @stage.save!
    
    sign_in_as(@user)
  end

  # 温度要件フィールド - 日本語ラベル
  test "should display Japanese temperature requirement labels" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    # 温度要件のラベル
    assert_select "label.form-label", text: /最低限界温度/
    assert_select "label.form-label", text: /最適温度 最小/
    assert_select "label.form-label", text: /最適温度 最大/
    assert_select "label.form-label", text: /低温ストレス閾値/
    assert_select "label.form-label", text: /高温ストレス閾値/
    assert_select "label.form-label", text: /霜害閾値/
    assert_select "label.form-label", text: /不稔リスク閾値/
    assert_select "label.form-label", text: /最大限界温度/
  end

  # 温度要件フィールド - 英語ラベル
  test "should display English temperature requirement labels" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    # 温度要件のラベル
    assert_select "label.form-label", text: /Base Temperature/
    assert_select "label.form-label", text: /Optimal Min/
    assert_select "label.form-label", text: /Optimal Max/
    assert_select "label.form-label", text: /Low Stress Threshold/
    assert_select "label.form-label", text: /High Stress Threshold/
    assert_select "label.form-label", text: /Frost Threshold/
    assert_select "label.form-label", text: /Sterility Risk Threshold/
    assert_select "label.form-label", text: /Max Temperature/
  end

  # 熱要件フィールド - 日本語ラベル
  test "should display Japanese thermal requirement labels" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select "label.form-label", text: /必要積算温度/
    assert_select ".form-text", text: /生育度日/
  end

  # 熱要件フィールド - 英語ラベル
  test "should display English thermal requirement labels" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select "label.form-label", text: /Required GDD/
    assert_select ".form-text", text: /Growing Degree Days/
  end

  # 日照要件フィールド - 日本語ラベル
  test "should display Japanese sunshine requirement labels" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select "label.form-label", text: /最低日照時間/
    assert_select "label.form-label", text: /目標日照時間/
  end

  # 日照要件フィールド - 英語ラベル
  test "should display English sunshine requirement labels" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select "label.form-label", text: /Minimum Sunshine Hours/
    assert_select "label.form-label", text: /Target Sunshine Hours/
  end

  # プレースホルダー - 日本語
  test "should display Japanese placeholders in requirement fields" do
    get edit_crop_path(@crop, locale: :ja)
    assert_response :success
    
    assert_select "input[placeholder*='例']", minimum: 1
  end

  # プレースホルダー - 英語
  test "should display English placeholders in requirement fields" do
    get edit_crop_path(@crop, locale: :us)
    assert_response :success
    
    assert_select "input[placeholder*='e.g.']", minimum: 1
  end
end

