# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class SaveAdjustedAgrrPlanSummaryAttrs
        attr_reader :summary,
                    :total_profit,
                    :total_revenue,
                    :total_cost,
                    :optimization_time,
                    :algorithm_used,
                    :is_optimal,
                    :status

        def initialize(
          summary:,
          total_profit:,
          total_revenue:,
          total_cost:,
          optimization_time:,
          algorithm_used:,
          is_optimal:,
          status: "completed"
        )
          @summary = summary
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          @optimization_time = optimization_time
          @algorithm_used = algorithm_used
          @is_optimal = is_optimal
          @status = status
          freeze
        end
      end
    end
  end
end
