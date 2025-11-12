# frozen_string_literal: true

require "application_system_test_case"

# シンプルな肥料AIボタンのテスト（application.jsがなくても動作確認できる基本テスト）
class FertilizeAiButtonSimpleTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: 'fertilize_ai_simple_test@example.com',
      name: 'Fertilize AI Simple Test User',
      google_id: "fertilize_ai_simple_#{SecureRandom.hex(8)}"
    )
    login_as_system_user(@user)
  end

  test "肥料新規登録ページにアクセスできる" do
    visit new_fertilize_path
    assert_current_path new_fertilize_path
    assert_selector 'form', text: /肥料/
  end

  test "肥料名入力フィールドが存在する" do
    visit new_fertilize_path
    assert_field 'fertilize[name]'
  end

  test "AIボタンのHTML要素が存在する" do
    visit new_fertilize_path
    
    # data-controller属性を持つボタンが存在することを確認
    button = page.find('button[data-controller="fertilize-ai"]', match: :first)
    assert button.present?
    assert_equal 'fertilize-ai', button['data-controller']
  end

  test "AIボタンに必要なdata属性が設定されている" do
    visit new_fertilize_path
    button = page.find('button[data-controller="fertilize-ai"]', match: :first)
    
    # 必要なdata属性が存在することを確認
    assert button['data-enter-name'].present?, "data-enter-nameが設定されていません"
    assert button['data-fetching'].present?, "data-fetchingが設定されていません"
    assert button['data-button-fetching'].present?, "data-button-fetchingが設定されていません"
  end

  test "AIボタンにアクセシビリティ属性が付与されている" do
    visit new_fertilize_path
    button = page.find('button[data-controller="fertilize-ai"]', match: :first)

    assert_equal "button", button.tag_name
    assert button["aria-live"].present?, "AIボタンにaria-liveが設定されていません"
    assert button["aria-controls"].present?, "AIボタンにaria-controlsが設定されていません"
    assert button["aria-describedby"].present?, "AIボタンにaria-describedbyが設定されていません"
  end

  test "キーボード操作でもAIボタンを利用できる" do
    visit new_fertilize_path

    find("body").send_keys(:tab) until page.evaluate_script("document.activeElement && document.activeElement.id === 'ai-save-fertilize-btn'")
    page.driver.browser.switch_to.active_element.send_keys(:enter)

    assert_selector "#ai-save-status", wait: 3
    status = find("#ai-save-status", visible: :all)
    assert_match(/肥料名を入力してください|AIで肥料情報を取得/, status.text)
  end

  test "編集画面でもAIボタンが存在する" do
    fertilize = Fertilize.create!(
      name: 'テスト肥料_編集',
      n: 10.0,
      p: 5.0,
      k: 5.0,
      is_reference: false,
      user: @user
    )
    
    visit edit_fertilize_path(fertilize)
    assert_selector 'button[data-controller="fertilize-ai"]', match: :first
  end
end


