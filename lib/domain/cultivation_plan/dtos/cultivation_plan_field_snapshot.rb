# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 圃場行の永続化結果（REST add_field 成功・イベント用）。
      class CultivationPlanFieldSnapshot
        attr_reader :id, :name, :area, :cultivation_count

        def initialize(id:, name:, area:, cultivation_count: 0)
          @id = id
          @name = name
          @area = area
          @cultivation_count = cultivation_count
          freeze
        end
      end
    end
  end
end
