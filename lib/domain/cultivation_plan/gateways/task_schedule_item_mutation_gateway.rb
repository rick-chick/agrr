# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 計画タスク予定 API 用の永続化（Adapter が AR を扱う）
      class TaskScheduleItemMutationGateway
        def find_item_for_plan(plan, item_id)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def create_item!(plan, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

        def update_item!(item, attributes)
          raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
        end

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
