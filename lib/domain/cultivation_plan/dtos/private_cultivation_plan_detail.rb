# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 所有者に紐づくプライベート計画の読み取り専用スナップショット（Gateway が返す形）。
      # HTML / ガント data-* などの表現は知らない（Assembler / 行ハッシュ化で付与する）。
      class PrivateCultivationPlanDetail
        FieldCultivationRead = Struct.new(
          :id,
          :cultivation_plan_field_id,
          :field_display_name,
          :cultivation_plan_crop_id,
          :crop_display_name,
          :start_date,
          :completion_date,
          :cultivation_days,
          :area,
          :estimated_cost,
          :optimization_profit,
          keyword_init: true
        )
        PlanFieldRead = Struct.new(:id, :name, :area, keyword_init: true)

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
                    :palette_used_crop_ids,
                    :palette_crops

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
          palette_used_crop_ids:,
          palette_crops:
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
          @palette_crops = palette_crops
        end
      end
    end
  end
end
