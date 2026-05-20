# frozen_string_literal: true

require "test_helper"

class TaskScheduleBlueprintsBoardViewTest < ActiveSupport::TestCase
  test "AI作業テンプレートをカードボード形式で表示する" do
    # id は seed 済み参照 crop と衝突しない値にする。
    # 衝突すると crop.crop_stages が WHERE crop_id=? で seed 側の stage を拾う。
    crop = Crop.new(
      id: 999_999,
      name: "AIボードテスト作物",
      is_reference: true
    )

    thermal_requirement = ThermalRequirement.new(
      required_gdd: 150.0
    )
    stage = CropStage.new(
      name: "開花期",
      order: 1,
      thermal_requirement: thermal_requirement
    )
    stage.crop = crop
    crop.crop_stages << stage

    agricultural_task = AgriculturalTask.new(
      id: 1,
      name: "摘花",
      description: "テスト用のAI生成作業",
      is_reference: true
    )

    blueprint = CropTaskScheduleBlueprint.new(
      id: 1,
      crop: crop,
      agricultural_task: agricultural_task,
      stage_order: 1,
      stage_name: "開花期",
      gdd_trigger: 150.0,
      gdd_tolerance: 15.0,
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: "agrr",
      priority: 2,
      time_per_sqm: 1.5
    )

    I18n.with_locale(:ja) do
      html = ApplicationController.renderer.render(
        partial: "crops/task_schedule_blueprints_section",
        locals: {
          crop: crop,
          task_schedule_blueprints: [blueprint]
        }
      )

      assert_includes html, "task-schedule-blueprints-board"

      gdd_axis_label = I18n.t("crops.show.task_schedule_blueprints_axis_gdd_total", total: 150)
      assert_includes html, gdd_axis_label

      # カードルート div は class="task-blueprint-card " で始まる（後続にバリアント class が続く）。
      # task-blueprint-card__header / __title など子要素を数えないよう末尾スペースまで含めて照合する。
      assert_match(/class="task-blueprint-card /, html)
      assert_equal 1, html.scan(/class="task-blueprint-card /).count

      assert_includes html, agricultural_task.name
      assert_match(/data-gdd-trigger="150\.0"/, html)
      assert_match(/data-order="1"/, html)
    end
  end
end
