# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # ワークベンチ GET の計画ヘッダー（永続から写した値のみ）。
      class CultivationPlanWorkbenchPlanHeader
        attr_reader :id, :plan_year, :plan_name, :plan_type, :status, :total_area,
                    :planning_start_date, :planning_end_date,
                    :total_profit, :total_revenue, :total_cost

        def initialize(
          id:, plan_year:, plan_name:, plan_type:, status:, total_area:,
          planning_start_date:, planning_end_date:,
          total_profit:, total_revenue:, total_cost:
        )
          @id = id
          @plan_year = plan_year
          @plan_name = plan_name
          @plan_type = plan_type
          @status = status
          @total_area = total_area
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          freeze
        end
      end
    end
  end
end
