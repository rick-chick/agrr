# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 計画に紐づく field_cultivation 集合の望ましい状態（`FieldCultivationSyncInteractor` 入力）。
      class FieldCultivationSyncInput
        attr_reader :field_schedules,
                    :optimization_summary,
                    :total_profit,
                    :total_revenue,
                    :total_cost,
                    :optimization_time,
                    :algorithm_used,
                    :is_optimal

        def initialize(
          field_schedules:,
          optimization_summary: nil,
          total_profit: nil,
          total_revenue: nil,
          total_cost: nil,
          optimization_time: nil,
          algorithm_used: nil,
          is_optimal: nil
        )
          @field_schedules = field_schedules.freeze
          @optimization_summary = optimization_summary
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          @optimization_time = optimization_time
          @algorithm_used = algorithm_used
          @is_optimal = is_optimal
        end
      end
    end
  end
end
