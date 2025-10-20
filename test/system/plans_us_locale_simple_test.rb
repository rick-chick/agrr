# frozen_string_literal: true

require "application_system_test_case"

# US ロケールでの Plans 翻訳シンプルテスト
class PlansUsLocaleSimpleTest < ApplicationSystemTestCase
  setup do
    @user = users(:developer)
    @farm = farms(:farm_tokyo)
    
    # ログイン
    visit auth_test_mock_login_path
  end
  
  test "US locale: plans index page displays correct translations" do
    visit plans_path(locale: :us)
    
    # ページタイトルが正しく翻訳されていることを確認
    assert_selector "h1", text: "Cultivation Plans"
    assert_text "Manage your yearly cultivation plans"
    assert_selector "a", text: "+ Create New Plan"
  end
  
  test "US locale: new plan page displays correct translations" do
    visit new_plan_path(locale: :us)
    
    # ページタイトルと説明文が正しく翻訳されていることを確認
    assert_selector "h2", text: "📅 Select Year and Farm"
    assert_text "Choose the year and farm for your cultivation plan"
    
    # フォームラベルが正しく翻訳されていることを確認
    assert_selector "label", text: "Plan Year"
    assert_selector "label", text: "Plan Name"
    assert_selector "label", text: "Farm"
  end
  
  test "IN locale (Hindi): plans index page displays correct translations" do
    visit plans_path(locale: :in)
    
    # ヒンディー語の翻訳が正しく表示されることを確認
    assert_selector "h1", text: "खेती योजनाएँ"
    assert_text "वार्षिक योजनाओं का प्रबंधन करें"
    assert_selector "a", text: "+ नई योजना बनाएं"
  end
  
  test "IN locale (Hindi): new plan page displays correct translations" do
    visit new_plan_path(locale: :in)
    
    # ヒンディー語の翻訳が正しく表示されることを確認
    assert_selector "h2", text: "📅 वर्ष और खेत चुनें"
    assert_text "अपनी खेती योजना के लिए वर्ष और खेत चुनें"
    
    # フォームラベルが正しく翻訳されていることを確認
    assert_selector "label", text: "योजना वर्ष"
    assert_selector "label", text: "योजना नाम"
    assert_selector "label", text: "खेत"
  end
  
  test "JA locale: plans index page displays correct translations" do
    visit plans_path(locale: :ja)
    
    # 日本語の翻訳が正しく表示されることを確認
    assert_selector "h1", text: "計画一覧"
    assert_text "年度別の計画を管理"
    assert_selector "a", text: "+ 新しい計画を作成"
  end
  
  test "All three locales are accessible for plans pages" do
    [:ja, :us, :in].each do |locale|
      visit plans_path(locale: locale)
      assert_selector "h1"
      
      visit new_plan_path(locale: locale)
      assert_selector "h2"
    end
  end
end

