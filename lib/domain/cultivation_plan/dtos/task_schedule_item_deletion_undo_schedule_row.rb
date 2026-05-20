# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作業予定削除 Undo スケジュール用の最小行（Mutation Gateway が返す）。
      class TaskScheduleItemDeletionUndoScheduleRow
        attr_reader :resource_type, :resource_id, :item_name

        def initialize(resource_type:, resource_id:, item_name:)
          @resource_type = resource_type
          @resource_id = resource_id
          @item_name = item_name
        end
      end
    end
  end
end
