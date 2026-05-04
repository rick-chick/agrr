# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 計画タスク予定 API 用の永続化（Adapter が AR を扱う）
      class TaskScheduleItemMutationGateway
        # @return [Hash] `serialize_item` 相当のスナップショット（Interactor は AR を受け取らない）
        def create_item!(plan, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後のスナップショット。見つからない場合は RecordNotFound（Adapter）
        def update_item_for_plan!(plan, item_id, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後のスナップショット。見つからない場合は RecordNotFound（Adapter）
        def complete_item_for_plan!(plan, item_id, actual_date:, actual_notes:, completed_at:)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
