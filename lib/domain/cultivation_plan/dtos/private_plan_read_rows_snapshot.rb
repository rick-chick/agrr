# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 私有計画 show 用の読み取り行（パレット作物は CropGateway + Mapper で付与）。
      class PrivatePlanReadRowsSnapshot
        attr_reader :id,
                    :display_name,
                    :farm_display_name,
                    :total_area,
                    :field_cultivations_count,
                    :cultivation_plan_fields_count,
                    :planning_start_date,
                    :planning_end_date,
                    :status,
                    :field_cultivations,
                    :cultivation_plan_fields,
                    :palette_used_crop_ids

        def initialize(
          id:,
          display_name:,
          farm_display_name:,
          total_area:,
          field_cultivations_count:,
          cultivation_plan_fields_count:,
          planning_start_date:,
          planning_end_date:,
          status:,
          field_cultivations:,
          cultivation_plan_fields:,
          palette_used_crop_ids:
        )
          @id = id
          @display_name = display_name
          @farm_display_name = farm_display_name
          @total_area = total_area
          @field_cultivations_count = field_cultivations_count
          @cultivation_plan_fields_count = cultivation_plan_fields_count
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @status = status
          @field_cultivations = field_cultivations
          @cultivation_plan_fields = cultivation_plan_fields
          @palette_used_crop_ids = palette_used_crop_ids
        end
      end
    end
  end
end
