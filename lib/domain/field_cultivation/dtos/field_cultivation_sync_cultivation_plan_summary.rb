# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期と同時に CultivationPlan に書き込む最適化サマリ列。
      class FieldCultivationSyncCultivationPlanSummary
        attr_reader :optimization_summary,
                    :total_profit,
                    :total_revenue,
                    :total_cost,
                    :optimization_time,
                    :algorithm_used,
                    :is_optimal,
                    :status

        def initialize(
          optimization_summary:,
          total_profit:,
          total_revenue:,
          total_cost:,
          optimization_time:,
          algorithm_used:,
          is_optimal:,
          status: "completed"
        )
          @optimization_summary = optimization_summary
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
