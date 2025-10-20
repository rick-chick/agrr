# frozen_string_literal: true

require "application_system_test_case"

# 全33ページのカバレッジテスト
# 各ページが正しく表示されることを確認
class AllPagesCoverageTest < ApplicationSystemTestCase
  def setup
    @user = User.create!(
      email: "coverage_test@example.com",
      name: "Coverage Test User",
      google_id: "coverage_#{SecureRandom.hex(8)}"
    )
    
    # テストデータのセットアップ
    @farm = Farm.create!(
      user: @user,
      name: "カバレッジテスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: "カバレッジテスト圃場",
      area: 1000
    )
    
    @crop = Crop.create!(
      user_id: @user.id,
      name: "カバレッジテスト作物",
      variety: "テスト品種"
    )
    
    @interaction_rule = InteractionRule.create!(
      user_id: @user.id,
      rule_type: 'continuous_cultivation',
      source_group: 'TestGroup',
      target_group: 'TestGroup',
      impact_ratio: 0.8
    )
  end
  
  # ========================================
  # 公開ページ（認証不要）- 10ページ
  # ========================================
  
  test "page 01: トップページが表示される" do
    visit root_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 02: プライバシーポリシーが表示される" do
    visit privacy_path
    assert_selector "h1"
    assert_text /プライバシー/i
  end
  
  test "page 03: 利用規約が表示される" do
    visit terms_path
    assert_selector "h1"
    assert_text /利用規約/i
  end
  
  test "page 04: お問い合わせページが表示される" do
    visit contact_path
    assert_selector "h1"
    assert_text /お問い合わせ/i
  end
  
  test "page 05: AGRRについてページが表示される" do
    visit about_path
    assert_selector "h1"
    assert_text /AGRR/i
  end
  
  test "page 06: 無料作付け計画 新規ページが表示される" do
    visit public_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 07: 無料作付け計画 農場サイズ選択が表示される" do
    visit select_farm_size_public_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 08: 無料作付け計画 作物選択が表示される" do
    visit select_crop_public_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 09: 無料作付け計画 最適化中ページが表示される" do
    visit optimizing_public_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 10: 無料作付け計画 結果ページが表示される" do
    visit results_public_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  # ========================================
  # 認証必要ページ（開発環境）- 2ページ
  # ========================================
  
  test "page 11: ログインページが表示される" do
    skip "Production環境では無効" if Rails.env.production?
    
    visit auth_login_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 12: モックログインページが表示される" do
    skip unless Rails.env.development? || Rails.env.test?
    
    visit auth_test_mock_login_path
    assert_selector "body"
    assert_response :success
  end
  
  # ========================================
  # 認証必須ページ: 農場管理 - 8ページ
  # ========================================
  
  test "page 13: 農場一覧が表示される" do
    login_as(@user)
    visit farms_path
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 14: 農場詳細が表示される" do
    login_as(@user)
    visit farm_path(@farm)
    assert_selector "h1"
    assert_text @farm.name
  end
  
  test "page 15: 農場新規作成フォームが表示される" do
    login_as(@user)
    visit new_farm_path
    assert_selector "form"
    assert_response :success
  end
  
  test "page 16: 農場編集フォームが表示される" do
    login_as(@user)
    visit edit_farm_path(@farm)
    assert_selector "form"
    assert_field "farm[name]"
  end
  
  test "page 17: 圃場一覧が表示される" do
    login_as(@user)
    visit farm_fields_path(@farm)
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 18: 圃場詳細が表示される" do
    login_as(@user)
    visit farm_field_path(@farm, @field)
    assert_selector "h1"
    assert_text @field.name
  end
  
  test "page 19: 圃場新規作成フォームが表示される" do
    login_as(@user)
    visit new_farm_field_path(@farm)
    assert_selector "form"
    assert_field "field[name]"
  end
  
  test "page 20: 圃場編集フォームが表示される" do
    login_as(@user)
    visit edit_farm_field_path(@farm, @field)
    assert_selector "form"
    assert_field "field[name]"
  end
  
  # ========================================
  # 認証必須ページ: 作物管理 - 4ページ
  # ========================================
  
  test "page 21: 作物一覧が表示される" do
    login_as(@user)
    visit crops_path
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 22: 作物詳細が表示される" do
    login_as(@user)
    visit crop_path(@crop)
    assert_selector "h1"
    assert_text @crop.name
  end
  
  test "page 23: 作物新規作成フォームが表示される" do
    login_as(@user)
    visit new_crop_path
    assert_selector "form"
    assert_field "crop[name]"
  end
  
  test "page 24: 作物編集フォームが表示される" do
    login_as(@user)
    visit edit_crop_path(@crop)
    assert_selector "form"
    assert_field "crop[name]"
  end
  
  # ========================================
  # 認証必須ページ: 連作ルール管理 - 4ページ
  # ========================================
  
  test "page 25: ルール一覧が表示される" do
    login_as(@user)
    visit interaction_rules_path
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 26: ルール詳細が表示される" do
    login_as(@user)
    visit interaction_rule_path(@interaction_rule)
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 27: ルール新規作成フォームが表示される" do
    login_as(@user)
    visit new_interaction_rule_path
    assert_selector "form"
    assert_select "select[name='interaction_rule[rule_type]']"
  end
  
  test "page 28: ルール編集フォームが表示される" do
    login_as(@user)
    visit edit_interaction_rule_path(@interaction_rule)
    assert_selector "form"
    assert_select "select[name='interaction_rule[rule_type]']"
  end
  
  # ========================================
  # 認証必須ページ: 作付け計画 - 5ページ
  # ========================================
  
  test "page 29: 計画一覧が表示される" do
    login_as(@user)
    visit plans_path
    assert_selector "h1"
    assert_response :success
  end
  
  test "page 30: 計画詳細が表示される" do
    skip "計画データのセットアップが必要"
    # 実装時にテストデータをセットアップ
  end
  
  test "page 31: 計画新規作成フォームが表示される" do
    login_as(@user)
    visit new_plan_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 32: 作物選択ページが表示される" do
    login_as(@user)
    visit select_crop_plans_path
    assert_selector "body"
    assert_response :success
  end
  
  test "page 33: 最適化中ページが表示される" do
    skip "計画データのセットアップが必要"
    # 実装時にテストデータをセットアップ
  end
  
  # ========================================
  # ロケール切り替え確認
  # ========================================
  
  test "all public pages work with different locales" do
    [:ja, :us, :in].each do |locale|
      visit root_path(locale: locale)
      assert_response :success
      
      visit privacy_path(locale: locale)
      assert_response :success
      
      visit terms_path(locale: locale)
      assert_response :success
    end
  end
  
  private
  
  def login_as(user)
    session = Session.create_for_user(user)
    page.driver.browser.manage.add_cookie(
      name: 'session_id',
      value: session.session_id
    )
    visit root_path
  end
end

