# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 私有計画一覧: crops/fields 件数付き行。
      class PlanRowSnapshot
        attr_reader :id,
                    :farm_display_name,
                    :total_area,
                    :crops_count,
                    :fields_count,
                    :status,
                    :display_name,
                    :created_at

        def initialize(
          id:,
          farm_display_name:,
          total_area:,
          crops_count:,
          fields_count:,
          status:,
          display_name:,
          created_at:
        )
          @id = id
          @farm_display_name = farm_display_name
          @total_area = total_area
          @crops_count = crops_count
          @fields_count = fields_count
          @status = status
          @display_name = display_name
          @created_at = created_at
          freeze
        end
      end
    end
  end
end
