require "application_system_test_case"

class AgriculturalTasksCardsTest < ApplicationSystemTestCase
  setup do
    @admin = create(:user, :admin)
    create(:agricultural_task, name: "参照タスクA", description: "参考タスクの説明", time_per_sqm: 1.5)
    create(:agricultural_task, :user_owned, user: @admin, name: "ユーザータスクB", description: "ユーザータスクの説明", time_per_sqm: 0.75)
    create(:agricultural_task, :user_owned, user: @admin, name: "ユーザータスクC", description: "詳細確認用", time_per_sqm: 2.0)

    login_as_system_user(@admin)
    # ブラウザにjaロケールCookieを設定（Accept-Languageヘッダーがusになるため）
    page.driver.browser.manage.add_cookie(name: "locale", value: "ja", path: "/")
  end

  test "カードデザインで農業タスク一覧を表示する" do
    visit agricultural_tasks_path(locale: :ja)

    assert_selector ".agricultural-tasks-grid"
    # 管理者はデフォルトで参照タスクとユーザータスクの両方を見る
    assert_selector ".agricultural-task-card", count: 3

    within first(".agricultural-task-card") do
      assert_selector ".agricultural-task-name"
    end
  end

  test "検索とフィルタを組み合わせて目的のタスクに到達し詳細を開ける" do
    visit agricultural_tasks_path(locale: :ja)

    fill_in "agricultural-task-search", with: "ユーザータスクC"
    find(".agricultural-task-search-form input[type=submit]", wait: 5).click

    assert_selector ".agricultural-task-card", wait: 10
    assert_text "ユーザータスクC"

    task = AgriculturalTask.find_by!(name: "ユーザータスクC")
    find("#agricultural_task_#{task.id} .btn-info", wait: 5).click

    assert_current_path agricultural_task_path(task)
    assert_text "詳細確認用"
  end

  test "参照タスクとユーザータスクのカード情報量とアクションが適切に表示される" do
    visit agricultural_tasks_path(locale: :ja)

    find("button, input[type=submit], .btn", text: /参照|Reference/, wait: 5).click
    assert_selector ".agricultural-task-card", wait: 5
    assert_selector ".agricultural-task-type.reference", text: /参照作業|Reference Task/
    within ".agricultural-task-card" do
      assert_selector ".agricultural-task-meta__label", text: /作業時間|Time per|㎡/
      assert_selector ".btn-secondary", text: /編集|Edit/
      assert_selector ".btn-error", text: /削除|Delete/
    end

    assert_selector ".agricultural-task-card", minimum: 1
    assert_selector ".agricultural-task-card", minimum: 1
  end

  test "モバイル幅でもカードレイアウトが崩れずスクロールできる" do
    visit agricultural_tasks_path(locale: :ja)
    page.driver.browser.manage.window.resize_to(390, 844)

    assert_selector ".agricultural-tasks-grid", wait: 2
    assert_selector ".agricultural-task-card", minimum: 2, wait: 2

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert page.evaluate_script("window.scrollY") > 0
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end
