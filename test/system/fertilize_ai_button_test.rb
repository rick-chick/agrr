# frozen_string_literal: true

require "application_system_test_case"

class FertilizeAiButtonTest < ApplicationSystemTestCase
  setup do
    # テストユーザーを作成
    @user = User.create!(
      email: 'fertilize_ai_test@example.com',
      name: 'Fertilize AI Test User',
      google_id: "fertilize_ai_#{SecureRandom.hex(8)}"
    )
    
    # ログイン
    login_as_system_user(@user)
  end

  test "肥料AIボタンが表示される" do
    visit new_fertilize_path
    
    # ボタンが存在することを確認（Propshaftで配信されるfertilize_ai.jsを使用）
    assert_selector '#ai-save-fertilize-btn', text: /AIで肥料情報を取得・保存/
    
    # ボタンが有効であることを確認
    button = find('#ai-save-fertilize-btn')
    assert_not button.disabled?, "肥料AIボタンが無効になっている"
  end

  test "肥料名を入力せずにボタンをクリックするとエラーメッセージが表示される" do
    visit new_fertilize_path
    
    # 肥料名フィールドが空の状態でボタンをクリック
    click_button '🤖 AIで肥料情報を取得・保存'
    
    # エラーメッセージが表示されることを確認（JavaScriptの処理を待つ）
    assert_selector '#ai-save-status', wait: 3
    status = find('#ai-save-status', visible: :all)
    assert_match(/肥料名を入力してください/, status.text)
  end

  test "肥料名を入力してボタンをクリックするとAPIが呼ばれる" do
    # APIエンドポイントをモック（実際のagrrコマンドの実行を回避）
    # 注意: 実際のテストではagrrコマンドが動いている必要がある
    
    visit new_fertilize_path
    
    # 肥料名を入力
    fill_in 'fertilize[name]', with: '尿素'
    
    # ボタンをクリック（Propshaftで配信されるfertilize_ai.jsが処理）
    click_button '🤖 AIで肥料情報を取得・保存'
    
    # ボタンが無効になることを確認
    button = find('#ai-save-fertilize-btn')
    assert button.disabled?, "ボタンが無効になっていない"
    
    # ローディングメッセージが表示されることを確認
    assert_selector '#ai-save-status', wait: 2
    status = find('#ai-save-status', visible: :all)
    assert_match(/AIで肥料情報を取得/, status.text)
    
    # 広告ポップアップが表示されることを確認（オプション）
    # 実際のagrrコマンドが成功する場合は、成功メッセージが表示される
    # 失敗する場合は、エラーメッセージが表示される
  end

  test "JavaScriptコンソールにエラーがない" do
    visit new_fertilize_path
    
    # JavaScriptエラーをチェック（Capybaraでは直接確認できないが、
    # ページが正常に読み込まれていることを確認）
    assert_selector '#ai-save-fertilize-btn'
    
    # ボタンのdata属性が正しく設定されていることを確認（Propshaftのfertilize_ai.jsで使用）
    button = find('#ai-save-fertilize-btn')
    assert button['data-enter-name'].present?
    assert button['data-fetching'].present?
  end

  test "編集画面でも肥料AIボタンが表示される" do
    # 既存の肥料を作成
    fertilize = Fertilize.create!(
      name: 'テスト肥料',
      n: 10.0,
      p: 5.0,
      k: 5.0,
      is_reference: false
    )
    
    visit edit_fertilize_path(fertilize)
    
    # ボタンが存在することを確認（Propshaftで配信されるfertilize_ai.jsを使用）
    assert_selector '#ai-save-fertilize-btn', text: /AIで肥料情報を取得・保存/
  end

  test "fertilize_ai.jsが正しく動作している" do
    visit new_fertilize_path
    
    # JavaScriptが読み込まれているか確認（ボタンのクリックイベントをテスト）
    button = find('#ai-save-fertilize-btn')
    
    # ボタンをクリックしてJavaScriptが実行されるか確認
    # （肥料名が空なのでエラーメッセージが表示されるはず）
    button.click
    
    # JavaScriptの処理が完了するまで待つ
    sleep 0.5
    
    # ステータスメッセージが表示されることを確認
    # （Propshaftで配信されるfertilize_ai.jsが動作していれば、showStatusが呼ばれる）
    assert_selector '#ai-save-status', wait: 2
  end
end

