# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 計画タスク予定 API 用の永続化（Adapter が AR を扱う）
      class TaskScheduleItemMutationGateway
        def find_item_for_plan(plan, item_id)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] `serialize_item` 相当のスナップショット（Interactor は AR を受け取らない）
        def create_item!(plan, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後の `serialize_item` 相当
        def update_item!(item, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        # @return [Hash] 永続化後の `serialize_item` 相当
        def complete_item!(item, actual_date:, actual_notes:, completed_at:)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def serialize_item(item)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end
      end
    end
  end
end
