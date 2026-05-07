# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 計画タスク予定 API 用の永続化（Adapter が AR を扱う）
      class TaskScheduleItemMutationGateway
        # @param user_id [Integer] 計画の所有者（プライベート計画スコープに使用）
        # @param plan_id [Integer,#to_i] 対象計画 ID
        # @return [Hash] `serialize_item` 相当のスナップショット
        def create_item!(user_id, plan_id, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後のスナップショット。計画・アイテムがスコープ外なら RecordNotFound（Adapter）
        def update_item_for_plan!(user_id, plan_id, item_id, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後のスナップショット。計画・アイテムがスコープ外なら RecordNotFound（Adapter）
        def complete_item_for_plan!(user_id, plan_id, item_id, actual_date:, actual_notes:, completed_at:)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # 削除 Undo スケジュール用に、アイテムの type/id/表示名だけを返す（Interactor に AR を載せない）。
        # @return [Hash] `:resource_type` (String), `:resource_id` (Integer), `:item_name` (String) の symbol キー
        def deletion_undo_schedule_row_for_item!(user_id, plan_id, item_id)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
