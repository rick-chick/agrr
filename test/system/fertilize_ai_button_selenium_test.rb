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
    login_as_system_user(@user)
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

  test "AIボタン成功時に広告ポップアップが閉じて詳細ページへ遷移する" do
    stub = install_fertilize_ai_stub(success_response: {
      "fertilize" => {
        "name" => "Selenium尿素",
        "n" => 46.0,
        "p" => 0.0,
        "k" => 0.0,
        "description" => "Selenium成功",
        "package_size" => "25kg"
      }
    })

    visit new_fertilize_path
    fill_in 'fertilize[name]', with: 'Selenium尿素'
    find('#ai-save-fertilize-btn').click

    assert_selector '#ad-popup-overlay.show', wait: 3
    assert eventually(timeout: 5) { stub.create_calls.size == 1 }
    assert eventually(timeout: 5) { current_path.match?(/\/fertilizes\/\d+/) }
  ensure
    remove_fertilize_ai_stub
  end

  test "AIボタン失敗時にポップアップが閉じてボタンが再度有効になる" do
    install_fertilize_ai_stub(error_response: {
      "success" => false,
      "error" => "Seleniumテスト失敗",
      "code" => "daemon_not_running"
    })

    visit new_fertilize_path
    fill_in 'fertilize[name]', with: 'Selenium失敗'
    button = find('#ai-save-fertilize-btn')
    button.click

    assert_selector '#ai-save-status', text: /Seleniumテスト失敗/, wait: 5, visible: :all
    status = find('#ai-save-status', visible: :all)
    assert eventually { !button.disabled? }
    assert eventually { !page.find('#ad-popup-overlay')[:class].include?('show') }
  ensure
    remove_fertilize_ai_stub
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

  private

    def install_fertilize_ai_stub(success_response: nil, error_response: nil)
      stub = FertilizeAiGatewayStub.new(success_response: success_response, error_response: error_response)
      Rails.configuration.x.fertilize_ai_gateway = stub
      stub
    end

    def remove_fertilize_ai_stub
      Rails.configuration.x.fertilize_ai_gateway = nil
    end

    def eventually(timeout: 3, interval: 0.1)
      start_time = Time.current
      loop do
        result = yield
        return true if result
        raise "Condition not met within #{timeout} seconds" if Time.current - start_time > timeout
        sleep interval
      end
    end
end

