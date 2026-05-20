# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CultivationPlanGateway#apply_optimization_result 用の CultivationPlan 更新属性。
      class OptimizationApplyAttrs
        attr_reader :total_profit,
                    :total_revenue,
                    :total_cost,
                    :optimization_time,
                    :algorithm_used,
                    :is_optimal,
                    :optimization_summary

        def initialize(
          total_profit:,
          total_revenue:,
          total_cost:,
          optimization_time:,
          algorithm_used:,
          is_optimal:,
          optimization_summary:
        )
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          @optimization_time = optimization_time
          @algorithm_used = algorithm_used
          @is_optimal = is_optimal
          @optimization_summary = optimization_summary
          freeze
        end

        # @return [Hash] CultivationPlan#update! に渡す属性
        def to_active_record_attributes
          {
            total_profit: total_profit,
            total_revenue: total_revenue,
            total_cost: total_cost,
            optimization_time: optimization_time,
            algorithm_used: algorithm_used,
            is_optimal: is_optimal,
            optimization_summary: optimization_summary
          }
        end
      end
    end
  end
end
