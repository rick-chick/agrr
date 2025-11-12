# frozen_string_literal: true

require "application_system_test_case"

class TaskScheduleBlueprintsBoardTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(
      email: 'task_schedule_board_admin@example.com',
      name: 'タスクボード管理者',
      google_id: "task-board-admin-#{SecureRandom.hex(4)}",
      admin: true
    )

    login_as_system_user(@admin)

    @crop = Crop.create!(
      name: 'AIボードテスト作物',
      is_reference: true
    )

    @agricultural_task = AgriculturalTask.create!(
      name: '摘花',
      description: 'テスト用のAI生成作業',
      is_reference: true
    )

    CropTaskScheduleBlueprint.create!(
      crop: @crop,
      agricultural_task: @agricultural_task,
      stage_order: 1,
      stage_name: '開花期',
      gdd_trigger: 150.0,
      gdd_tolerance: 15.0,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: 'agrr',
      priority: 2,
      time_per_sqm: 1.5
    )
  end

  test "AI作業テンプレートをカードボード形式で表示する" do
    visit crop_path(@crop, locale: :ja)

    assert_selector '.task-schedule-blueprints-board'

    gdd_axis_label = I18n.t('crops.show.task_schedule_blueprints_axis_gdd_total', total: 150)

    assert_selector '.task-board-axis-label-x', text: gdd_axis_label

    cards = all('.task-blueprint-card')
    assert_equal 1, cards.count

    card = cards.first
    assert_includes card.text, @agricultural_task.name
    assert_equal '150.0', card['data-gdd-trigger']
    assert_equal '1', card['data-order']
  end
end

