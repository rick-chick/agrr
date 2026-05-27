# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # PlanCopy: TaskScheduleItem の参照農作業 id → ユーザー農作業 id（Adapter 内 AR 参照）。
    class PlanSaveTaskScheduleAgriculturalTaskResolver
      def initialize(
        user_id:,
        reference_agricultural_task_id_to_user_task_id:,
        plan_save_user_agricultural_task_gateway:
      )
        @user_id = user_id.to_i
        @reference_agricultural_task_id_to_user_task_id =
          reference_agricultural_task_id_to_user_task_id || {}
        @plan_save_user_agricultural_task_gateway = plan_save_user_agricultural_task_gateway
      end

      # @param reference_item [TaskScheduleItem]
      # @return [Integer, nil]
      def mapped_agricultural_task_id(reference_item)
        task = reference_item.agricultural_task
        return task.id if task&.user_id == @user_id

        reference_task_id = task&.id
        return nil unless reference_task_id

        PlanSaveAgriculturalTaskIdLookup.resolve(
          reference_task_id: reference_task_id,
          user_id: @user_id,
          map: @reference_agricultural_task_id_to_user_task_id,
          plan_save_user_agricultural_task_gateway: @plan_save_user_agricultural_task_gateway
        )
      end
    end
  end
end
