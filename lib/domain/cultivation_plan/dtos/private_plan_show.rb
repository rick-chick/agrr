# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画詳細（HTML show）用。ActiveRecord は含めない。
      # ガント初期 data-* 用の配列は app/views/shared/_gantt_chart 互換の Hash 形。
      class PrivatePlanShow
        attr_reader :id,
                    :display_name,
                    :farm_display_name,
                    :total_area,
                    :field_cultivations_count,
                    :cultivation_plan_fields_count,
                    :planning_start_date,
                    :planning_end_date,
                    :status,
                    :gantt_cultivation_rows,
                    :gantt_field_rows,
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
          gantt_cultivation_rows:,
          gantt_field_rows:,
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
          @gantt_cultivation_rows = gantt_cultivation_rows
          @gantt_field_rows = gantt_field_rows
          @palette_used_crop_ids = palette_used_crop_ids
          @palette_crops = palette_crops
        end

        def optimizing?
          PlanStatus.optimizing?(status)
        end
      end
    end
  end
end
