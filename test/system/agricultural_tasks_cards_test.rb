require "application_system_test_case"

class AgriculturalTasksCardsTest < ApplicationSystemTestCase
  setup do
    @admin = create(:user, :admin)
    create(:agricultural_task, name: "参照タスクA", description: "参考タスクの説明", time_per_sqm: 1.5)
    create(:agricultural_task, :user_owned, user: @admin, name: "ユーザータスクB", description: "ユーザータスクの説明", time_per_sqm: 0.75)
    create(:agricultural_task, :user_owned, user: @admin, name: "ユーザータスクC", description: "詳細確認用", time_per_sqm: 2.0)

    login_as_system_user(@admin)
  end

  test "カードデザインで農業タスク一覧を表示する" do
    visit agricultural_tasks_path

    assert_selector ".agricultural-tasks-grid"
    assert_selector ".agricultural-task-card", count: 2

    within first(".agricultural-task-card") do
      assert_selector ".agricultural-task-name"
    end
  end

  test "検索とフィルタを組み合わせて目的のタスクに到達し詳細を開ける" do
    visit agricultural_tasks_path

    fill_in "agricultural-task-search", with: "ユーザータスクC"
    click_button I18n.t("agricultural_tasks.index.actions.search")

    assert_selector ".agricultural-task-card", count: 1
    assert_text "ユーザータスクC"

    click_button I18n.t("agricultural_tasks.index.filters.user_tasks")
    assert_selector ".agricultural-task-card", count: 1
    assert_text "ユーザータスクC"

    within first(".agricultural-task-card") do
      click_link I18n.t("agricultural_tasks.index.actions.show")
    end

    assert_current_path agricultural_task_path(AgriculturalTask.find_by!(name: "ユーザータスクC"))
    assert_text "詳細確認用"
  end

  test "参照タスクとユーザータスクのカード情報量とアクションが適切に表示される" do
    visit agricultural_tasks_path

    click_button I18n.t("agricultural_tasks.index.filters.reference_tasks")
    assert_selector ".agricultural-task-card", count: 1
    assert_selector ".agricultural-task-type.reference", text: I18n.t("agricultural_tasks.index.reference_task")
    within ".agricultural-task-card" do
      assert_selector ".agricultural-task-meta__label", text: I18n.t("agricultural_tasks.index.time_per_sqm")
      assert_selector ".btn-secondary", text: I18n.t("agricultural_tasks.index.actions.edit")
      assert_selector ".btn-error", text: I18n.t("agricultural_tasks.index.actions.delete")
    end

    click_button I18n.t("agricultural_tasks.index.filters.user_tasks")
    assert_selector ".agricultural-task-card", count: 2
    assert_selector ".agricultural-task-type.user", text: I18n.t("agricultural_tasks.index.user_task_tag"), minimum: 1
  end

  test "モバイル幅でもカードレイアウトが崩れずスクロールできる" do
    visit agricultural_tasks_path
    page.driver.browser.manage.window.resize_to(390, 844)

    assert_selector ".agricultural-tasks-grid"
    assert_selector ".agricultural-task-card", minimum: 2

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert page.evaluate_script("window.scrollY") > 0
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end
end

