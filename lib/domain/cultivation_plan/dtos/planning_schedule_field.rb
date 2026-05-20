# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作付計画表で表示するほ場情報（読み取り専用）
      class PlanningScheduleField
        attr_reader :id, :name, :area, :farm_name

        def initialize(id:, name:, area:, farm_name:)
          @id = id
          @name = name
          @area = area
          @farm_name = farm_name
          freeze
        end
      end
    end
  end
end
