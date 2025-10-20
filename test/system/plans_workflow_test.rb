# frozen_string_literal: true

require "application_system_test_case"

class PlansWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:developer)
    @farm = farms(:farm_tokyo)
    
    # ユーザー作物を作成
    @crop1 = Crop.create!(
      name: "テストトマト",
      variety: "桃太郎",
      user: @user,
      is_reference: false,
      area_per_unit: 1.0,
      revenue_per_area: 1200.0
    )
    
    @crop2 = Crop.create!(
      name: "テストキュウリ",
      user: @user,
      is_reference: false,
      area_per_unit: 0.8,
      revenue_per_area: 900.0
    )
    
    # ログイン
    visit auth_test_mock_login_path
  end
  
  test "full workflow: create plan with crops selection" do
    # 計画一覧にアクセス
    visit plans_path
    assert_selector "h1", text: I18n.t('plans.index.title')
    
    # 新規計画作成
    click_link I18n.t('plans.index.create_new'), match: :first
    assert_selector "h2", text: I18n.t('plans.new.title')
    
    # 年度と農場を選択
    select "2025年度（2024年1月〜2026年12月）", from: "plan_year"
    choose "farm_id_#{@farm.id}"
    click_button I18n.t('plans.new.next_button')
    
    # 作物選択画面
    assert_selector "h2", text: I18n.t('plans.select_crop.title')
    
    # 作物を選択
    check "crop_#{@crop1.id}"
    check "crop_#{@crop2.id}"
    
    # カウンターが更新されることを確認
    assert_selector "#counter", text: "2"
    
    # 送信ボタンが有効になることを確認
    submit_btn = find("#submitBtn")
    assert_not submit_btn.disabled?
    
    # 計画を作成
    click_button I18n.t('plans.select_crop.bottom_bar.submit_button')
    
    # 最適化画面にリダイレクト
    assert_selector ".optimizing-card"
  end
  
  test "crop selection counter should update" do
    visit select_crop_plans_path(plan_year: 2025, farm_id: @farm.id, plan_name: "Test")
    
    # 初期状態: カウンター0、ボタン無効
    assert_selector "#counter", text: "0"
    submit_btn = find("#submitBtn")
    assert submit_btn.disabled?
    
    # 1つ選択
    check "crop_#{@crop1.id}"
    assert_selector "#counter", text: "1"
    assert_not find("#submitBtn").disabled?
    
    # もう1つ選択
    check "crop_#{@crop2.id}"
    assert_selector "#counter", text: "2"
    
    # 1つ解除
    uncheck "crop_#{@crop1.id}"
    assert_selector "#counter", text: "1"
    
    # 全て解除
    uncheck "crop_#{@crop2.id}"
    assert_selector "#counter", text: "0"
    assert find("#submitBtn").disabled?
  end
end

