# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作業予定アイテムの JSON/API 向けスナップショット（Mutation Gateway の返却型）。
      class TaskScheduleItemSnapshot
        attr_reader :id, :name, :scheduled_date, :status, :category

        def initialize(id:, name:, scheduled_date:, status:, category:)
          @id = id
          @name = name
          @scheduled_date = scheduled_date
          @status = status
          @category = category
        end

        def as_json(*)
          {
            id: id,
            name: name,
            scheduled_date: scheduled_date,
            status: status,
            category: category
          }
        end
      end
    end
  end
end
