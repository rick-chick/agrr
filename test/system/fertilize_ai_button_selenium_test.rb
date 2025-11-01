# frozen_string_literal: true

require "application_system_test_case"

# Seleniumで肥料AIボタンの動作を確認するテスト
class FertilizeAiButtonSeleniumTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: 'fertilize_ai_selenium_test@example.com',
      name: 'Fertilize AI Selenium Test User',
      google_id: "fertilize_ai_selenium_#{SecureRandom.hex(8)}"
    )
    
    # ログイン（肥料ページに直接アクセスしてapplication.jsエラーを回避）
    session = Session.create_for_user(@user)
    session.save!
    @user.reload
    
    visit new_fertilize_path
    page.driver.browser.manage.add_cookie(
      name: 'session_id',
      value: session.session_id,
      path: '/'
    )
    visit new_fertilize_path
  end

  test "肥料AIボタンが表示され、クリックできる" do
    # ボタンが存在することを確認（Propshaftで配信されるfertilize_ai.jsを使用）
    assert_selector '#ai-save-fertilize-btn', wait: 5
    
    button = find('#ai-save-fertilize-btn')
    assert button.present?, "肥料AIボタンが表示されていません"
    assert_not button.disabled?, "ボタンが無効になっています"
    
    # ボタンをクリック
    button.click
    
    # JavaScriptが動作したか確認（ステータスメッセージが表示される）
    # Propshaftで配信されるfertilize_ai.jsが動作すれば、エラーメッセージが表示される
    assert_selector '#ai-save-status', wait: 3, visible: :all
    
    status = find('#ai-save-status', visible: :all)
    assert_match(/肥料名を入力/, status.text, "エラーメッセージが表示されていません")
  end

  test "肥料名を入力してボタンをクリックするとAPIが呼ばれる" do
    # 肥料名を入力
    fill_in 'fertilize[name]', with: '尿素'
    
    # ボタンをクリック（Propshaftで配信されるfertilize_ai.jsが処理）
    button = find('#ai-save-fertilize-btn')
    button.click
    
    # ボタンが無効になることを確認
    assert button.disabled?, "ボタンが無効になっていません"
    
    # ローディングメッセージが表示されることを確認
    assert_selector '#ai-save-status', wait: 3, visible: :all
    status = find('#ai-save-status', visible: :all)
    assert_match(/AIで肥料情報を取得/, status.text, "ローディングメッセージが表示されていません")
  end

  test "fertilize_ai.jsが正しく読み込まれている" do
    # ページのソースを確認してfertilize_ai.jsの読み込みを確認
    page_source = page.html
    
    # javascript_include_tagでfertilize_aiが読み込まれているか確認
    assert_match(/fertilize_ai/, page_source, "fertilize_ai.jsが読み込まれていません")
    
    # ボタンのdata属性が正しく設定されていることを確認（Propshaftのfertilize_ai.jsで使用）
    button = find('#ai-save-fertilize-btn')
    assert button['data-enter-name'].present?, "data-enter-nameが設定されていません"
    assert button['data-fetching'].present?, "data-fetchingが設定されていません"
  end
end

