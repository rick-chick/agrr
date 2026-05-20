# frozen_string_literal: true

require "application_system_test_case"

class TaskScheduleBlueprintsBoardTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(
      email: "task_schedule_board_admin@example.com",
      name: "タスクボード管理者",
      google_id: "task-board-admin-#{SecureRandom.hex(4)}",
      admin: true
    )

    @session = Session.create_for_user(@admin)
    @session.save!
    @admin.reload

    @crop = Crop.create!(
      name: "AIボードテスト作物",
      is_reference: true
    )

    @agricultural_task = AgriculturalTask.create!(
      name: "摘花",
      description: "テスト用のAI生成作業",
      is_reference: true
    )

    CropTaskScheduleBlueprint.create!(
      crop: @crop,
      agricultural_task: @agricultural_task,
      stage_order: 1,
      stage_name: "開花期",
      gdd_trigger: 150.0,
      gdd_tolerance: 15.0,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: "agrr",
      priority: 2,
      time_per_sqm: 1.5
    )
  end

  test "AI作業テンプレートをカードボード形式で表示する" do
    login_and_visit_with_consent_fast crop_path(@crop, locale: :ja)

    assert_selector ".task-schedule-blueprints-board", wait: 1

    gdd_axis_label = I18n.t("crops.show.task_schedule_blueprints_axis_gdd_total", total: 150)

    assert_selector ".task-board-axis-label-x", text: gdd_axis_label, wait: 1

    cards = all(".task-blueprint-card", wait: 1)
    assert_equal 1, cards.count

    card = cards.first
    assert_includes card.text, @agricultural_task.name
    assert_equal "150.0", card["data-gdd-trigger"]
    assert_equal "1", card["data-order"]
  end

  private

  # /upヘルスチェックでドメインを確立（root_pathより軽量）・cookie同意をlocalStorageに設定
  def login_and_visit_with_consent_fast(url)
    visit rails_health_check_path
    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: @session.session_id,
      path: "/"
    )
    set_cookie_consent_granted
    visit url
  end
end
