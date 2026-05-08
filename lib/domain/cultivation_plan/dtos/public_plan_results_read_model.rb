# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開ウィザード「結果」の読み取りスナップショット（View / AR 非依存）
      class PublicPlanResultsReadModel
        attr_reader :plan_id, :status_completed, :planning_start_date, :planning_end_date,
                    :farm_name, :total_area, :field_cultivations_count,
                    :total_cost, :total_revenue, :total_profit,
                    :gantt_cultivation_rows, :gantt_field_rows, :crop_palette_embed,
                    :show_schedule_warning

        def initialize(plan_id:, status_completed:, planning_start_date:, planning_end_date:,
                       farm_name:, total_area:, field_cultivations_count:,
                       total_cost:, total_revenue:, total_profit:,
                       gantt_cultivation_rows:, gantt_field_rows:, crop_palette_embed:,
                       show_schedule_warning:)
          @plan_id = plan_id
          @status_completed = status_completed
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @farm_name = farm_name
          @total_area = total_area
          @field_cultivations_count = field_cultivations_count
          @total_cost = total_cost
          @total_revenue = total_revenue
          @total_profit = total_profit
          @gantt_cultivation_rows = gantt_cultivation_rows
          @gantt_field_rows = gantt_field_rows
          @crop_palette_embed = crop_palette_embed
          @show_schedule_warning = show_schedule_warning
        end
      end
    end
  end
end
