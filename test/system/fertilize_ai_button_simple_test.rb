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

  test "編集画面でもAIボタンが存在する" do
    fertilize = Fertilize.create!(
      name: 'テスト肥料_編集',
      n: 10.0,
      p: 5.0,
      k: 5.0,
      is_reference: false
    )
    
    visit edit_fertilize_path(fertilize)
    assert_selector 'button[data-controller="fertilize-ai"]', match: :first
  end
end


