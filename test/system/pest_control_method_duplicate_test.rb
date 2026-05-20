# frozen_string_literal: true

require "application_system_test_case"

class PestControlMethodDuplicateTest < ApplicationSystemTestCase
  setup do
    @user = create(:user, admin: true)
    login_as_system_user(@user)
    # ブラウザにjaロケールCookieを設定（Accept-Languageヘッダーがusになるため）
    page.driver.browser.manage.add_cookie(name: "locale", value: "ja", path: "/")
  end

  test "防除方法追加ボタンを1回クリックすると1つのパネルのみが追加される" do
    visit new_pest_path(locale: :ja)
    dismiss_cookie_consent

    # 初期状態を確認
    initial_count = page.all(".control-method-fields", visible: :all).count

    # 防除方法追加ボタンをクリック
    find("button", text: /防除方法を追加|Add Control Method/, wait: 5).click

    # 1つだけ追加されることを確認
    sleep 0.5  # JavaScriptの処理を待つ
    new_count = page.all(".control-method-fields", visible: :all).count
    assert_equal initial_count + 1, new_count, "防除方法パネルが1つだけ追加されるべき"
  end

  test "防除方法追加ボタンを2回クリックすると2つのパネルが追加される" do
    visit new_pest_path(locale: :ja)
    dismiss_cookie_consent

    # 初期状態を確認
    initial_count = page.all(".control-method-fields", visible: :all).count

    # 防除方法追加ボタンを2回クリック
    find("button", text: /防除方法を追加|Add Control Method/, wait: 5).click
    sleep 0.3
    find("button", text: /防除方法を追加|Add Control Method/, wait: 5).click

    # 2つ追加されることを確認
    sleep 0.5  # JavaScriptの処理を待つ
    new_count = page.all(".control-method-fields", visible: :all).count
    assert_equal initial_count + 2, new_count, "防除方法パネルが2つ追加されるべき"
  end

  test "turbo:loadイベント後も追加ボタンが1回のクリックで1つのパネルのみ追加する" do
    visit new_pest_path(locale: :ja)
    dismiss_cookie_consent

    # 初期状態を確認
    initial_count = page.all(".control-method-fields", visible: :all).count

    # turbo:loadイベントをシミュレート（ページ遷移を再現）
    page.execute_script("document.dispatchEvent(new Event('turbo:load'));")
    sleep 0.3

    # 防除方法追加ボタンをクリック
    find("button", text: /防除方法を追加|Add Control Method/, wait: 5).click

    # 1つだけ追加されることを確認（重複登録されていないことを確認）
    sleep 0.5
    new_count = page.all(".control-method-fields", visible: :all).count
    assert_equal initial_count + 1, new_count, "turbo:load後も1つのパネルのみ追加されるべき"
  end

  test "複数回のturbo:loadイベント後も追加ボタンが正常に動作する" do
    visit new_pest_path(locale: :ja)

    # 初期状態を確認
    initial_count = page.all(".control-method-fields", visible: :all).count

    # turbo:loadイベントを複数回発火（重複登録をシミュレート）
    page.execute_script(
      "document.dispatchEvent(new Event('turbo:load'));
       setTimeout(() => document.dispatchEvent(new Event('turbo:load')), 50);
       setTimeout(() => document.dispatchEvent(new Event('turbo:load')), 100);"
    )
    sleep 0.2

    # 防除方法追加ボタンを1回クリック
    find("button", text: /防除方法を追加|Add Control Method/).click

    # 1つだけ追加されることを確認（Capybara自動待機で重複登録されていないことを確認）
    assert_selector ".control-method-fields", count: initial_count + 1, wait: 1
  end

  test "編集画面でも防除方法追加ボタンが正常に動作する" do
    pest = create(:pest, :complete, is_reference: true)
    visit edit_pest_path(pest, locale: :ja)

    # 既存の防除方法を確認
    initial_count = page.all(".control-method-fields", visible: :all).count
    assert initial_count > 0, "編集画面には既存の防除方法が表示されるべき"

    # 防除方法追加ボタンをクリック
    find("button", text: /防除方法を追加|Add Control Method/).click

    # 1つだけ追加されることを確認（Capybara自動待機で確認）
    assert_selector ".control-method-fields", count: initial_count + 1, wait: 1
  end

  private

  def eventually(timeout: 3, interval: 0.2)
    start_time = Time.current
    loop do
      result = yield
      return true if result
      raise "Condition not met within #{timeout} seconds" if Time.current - start_time > timeout
      sleep interval
    end
  end
end
