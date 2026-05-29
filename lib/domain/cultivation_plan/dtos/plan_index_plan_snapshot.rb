# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 私有計画一覧: 計画 1 行（件数なし）。
      class PlanIndexPlanSnapshot
        attr_reader :id, :farm_display_name, :total_area, :status, :display_name, :created_at

        def initialize(id:, farm_display_name:, total_area:, status:, display_name:, created_at:)
          @id = id
          @farm_display_name = farm_display_name
          @total_area = total_area
          @status = status
          @display_name = display_name
          @created_at = created_at
          freeze
        end
      end
    end
  end
end
