# frozen_string_literal: true

require "test_helper"

module DeletionUndo
  class ManagerTest < ActiveSupport::TestCase
    setup do
      @user = create(:user)
    end

    test "schedule_deletes_plan_with_complex_associations" do
      plan = create(:cultivation_plan, user: @user, status: "completed")

      # 圃場を作成
      field = create(:cultivation_plan_field, cultivation_plan: plan)

      # 作物を作成（2つ）
      crop1 = create(:crop, user: @user, is_reference: false)
      crop2 = create(:crop, user: @user, is_reference: false)
      plan_crop1 = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop1)
      plan_crop2 = create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop2)

      # 作付を作成（FieldCultivationはCultivationPlanFieldとCultivationPlanCropの両方から参照される）
      field_cultivation1 = create(:field_cultivation,
                                  cultivation_plan: plan,
                                  cultivation_plan_field: field,
                                  cultivation_plan_crop: plan_crop1)
      field_cultivation2 = create(:field_cultivation,
                                  cultivation_plan: plan,
                                  cultivation_plan_field: field,
                                  cultivation_plan_crop: plan_crop2)

      # TaskScheduleを作成（field_cultivation_idを持つもの）
      task_schedule1 = create(:task_schedule,
                              cultivation_plan: plan,
                              field_cultivation: field_cultivation1,
                              category: "general")
      task_schedule2 = create(:task_schedule,
                              cultivation_plan: plan,
                              field_cultivation: nil,
                              category: "fertilizer")

      # TaskScheduleItemを作成
      create(:task_schedule_item, task_schedule: task_schedule1)
      create(:task_schedule_item, task_schedule: task_schedule2)

      # 計画が削除される前の状態を確認
      assert CultivationPlan.exists?(plan.id)
      assert FieldCultivation.exists?(field_cultivation1.id)
      assert FieldCultivation.exists?(field_cultivation2.id)

      # 計画を削除（FieldCultivation が Field/Crop 双方の dependent で二重 destroy されないこと）
      event = Manager.schedule(record: plan, actor: @user)

      assert_not_nil event, "削除イベントが作成されることを期待"
      assert_not CultivationPlan.exists?(plan.id), "計画が削除されることを期待"
    end
  end
end
