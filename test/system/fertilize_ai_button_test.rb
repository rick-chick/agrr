# frozen_string_literal: true

require "application_system_test_case"

class FertilizeAiButtonTest < ApplicationSystemTestCase
  setup do
    # テストユーザーを作成
    @user = User.create!(
      email: "fertilize_ai_test@example.com",
      name: "Fertilize AI Test User",
      google_id: "fertilize_ai_#{SecureRandom.hex(8)}"
    )

    # ログイン
    login_as_system_user(@user)
    # ブラウザにjaロケールCookieを設定（Accept-Languageヘッダーがusになるため）
    page.driver.browser.manage.add_cookie(name: "locale", value: "ja", path: "/")
    set_cookie_consent_granted
  end

  test "肥料AIボタンが表示される" do
    visit new_fertilize_path(locale: :ja)

    # ボタンが存在し有効であることを確認
    button = find("#ai-save-fertilize-btn", wait: 2)
    assert_match(/AIで肥料情報を取得・保存|Get & Save Fertilizer Info with AI/, button.text)
    assert_not button.disabled?, "肥料AIボタンが無効になっている"
  end

  test "肥料名を入力せずにボタンをクリックするとエラーメッセージが表示される" do
    visit new_fertilize_path(locale: :ja)

    # 肥料名フィールドが空の状態でボタンをクリック
    find("#ai-save-fertilize-btn").click

    # エラーメッセージが表示されることを確認（クライアント側バリデーションで即座に表示）
    assert_selector "#ai-save-status", wait: 0.5, visible: :all
    status = find("#ai-save-status", visible: :all)
    assert_match(/肥料名を入力してください|Enter fertilizer name/, status.text)
  end

  test "肥料名を入力してボタンをクリックするとAPIが呼ばれる" do
    stub = install_fertilize_ai_stub(error_response: {
      "success" => false,
      "error" => "テスト用エラー"
    })

    visit new_fertilize_path(locale: :ja)

    # 肥料名を入力
    fill_in "fertilize[name]", with: "尿素"

    # ボタンをクリック（Propshaftで配信されるfertilize_ai.jsが処理）
    find("#ai-save-fertilize-btn", wait: 2).click

    # ボタンが無効になることを確認
    button = find("#ai-save-fertilize-btn")
    assert button.disabled?, "ボタンが無効になっていない"

    # エラーメッセージが表示されることを確認
    assert_selector "#ai-save-status", text: /テスト用エラー/, wait: 1, visible: :all

    assert stub.create_calls.any? { |payload| payload[:name] == "尿素" }, "AI APIが呼び出されていません"
  ensure
    remove_fertilize_ai_stub
  end

  test "AIボタン成功フローで成功メッセージと詳細ページ遷移が行われる" do
    stub = install_fertilize_ai_stub(success_response: {
      "fertilize" => {
        "name" => "AI尿素",
        "n" => 46.0,
        "p" => 0.0,
        "k" => 0.0,
        "description" => "AI生成説明",
        "package_size" => "20kg"
      }
    })

    visit new_fertilize_path(locale: :ja)
    fill_in "fertilize[name]", with: "尿素"
    find("#ai-save-fertilize-btn", wait: 3).click

    assert_selector "#ai-save-status", text: /AI尿素/, wait: 3, visible: :all
    status = find("#ai-save-status", visible: :all)

    assert eventually(timeout: 3) { stub.create_calls.any? { |payload| payload[:name] == "尿素" } }, "AI APIが呼び出されていません"

    assert eventually(timeout: 3) { current_path.match?(/\/fertilizes\/\d+/) }, "詳細ページに遷移していません"
  ensure
    remove_fertilize_ai_stub
  end

  test "AIボタン失敗フローでエラー表示後ボタンが再度有効になる" do
    stub = install_fertilize_ai_stub(error_response: {
      "success" => false,
      "error" => "テスト用エラー"
    })

    visit new_fertilize_path(locale: :ja)
    fill_in "fertilize[name]", with: "失敗肥料"
    find("#ai-save-fertilize-btn").click

    assert_selector "#ai-save-status", text: /テスト用エラー/, wait: 2, visible: :all

    button = find("#ai-save-fertilize-btn")
    assert eventually(timeout: 2) { !button.disabled? }, "失敗後にボタンが再度有効化されていません"
  ensure
    remove_fertilize_ai_stub
  end


  test "編集画面でも肥料AIボタンが表示される" do
    # 既存の肥料を作成
    fertilize = Fertilize.create!(
      name: "テスト肥料",
      n: 10.0,
      p: 5.0,
      k: 5.0,
      is_reference: false,
      user: @user
    )

    visit edit_fertilize_path(fertilize, locale: :ja)

    # ボタンが存在することを確認（Propshaftで配信されるfertilize_ai.jsを使用）
    assert_selector "#ai-save-fertilize-btn", text: /AIで肥料情報を取得・保存/
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

    def eventually(timeout: 15, interval: 0.2)
      start_time = Time.current
      loop do
        result = yield
        return true if result
        raise "Condition not met within #{timeout} seconds" if Time.current - start_time > timeout
        sleep interval
      end
    end
end
