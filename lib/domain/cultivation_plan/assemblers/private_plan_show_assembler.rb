# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Assemblers
      class PrivatePlanShowAssembler
        def self.call(detail)
          new(detail).call
        end

        def initialize(detail)
          @detail = detail
        end

        def call
          Domain::CultivationPlan::Dtos::PrivatePlanShowDto.new(
            id: @detail.id,
            display_name: @detail.display_name,
            farm_display_name: @detail.farm_display_name,
            total_area: @detail.total_area,
            field_cultivations_count: @detail.field_cultivations_count,
            cultivation_plan_fields_count: @detail.cultivation_plan_fields_count,
            planning_start_date: @detail.planning_start_date,
            planning_end_date: @detail.planning_end_date,
            status: @detail.status,
            gantt_cultivation_rows: @detail.field_cultivations.map do |fc|
              GanttChartRowHashes.cultivation_row_from_read(fc)
            end,
            gantt_field_rows: @detail.cultivation_plan_fields.map do |f|
              GanttChartRowHashes.field_row_from_read(f)
            end,
            palette_used_crop_ids: @detail.palette_used_crop_ids,
            palette_crops: @detail.palette_crops
          )
        end
      end
    end
  end
end
