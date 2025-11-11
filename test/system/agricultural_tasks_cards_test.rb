require "application_system_test_case"

class AgriculturalTasksCardsTest < ApplicationSystemTestCase
  setup do
    @admin = create(:user, :admin)
    create(:agricultural_task, name: "参照タスクA")
    create(:agricultural_task, :user_owned, user: @admin, name: "ユーザータスクB")

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
end

