# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # adjust 成功応答に含まれる栽培計画サマリ（`plan_summary_for_adjust_response` + total_profit）。
      class CultivationPlanRestAdjustPlanSummary
        attr_reader :id, :field_cultivations_count, :total_profit

        def initialize(id:, field_cultivations_count:, total_profit: nil)
          @id = id
          @field_cultivations_count = field_cultivations_count
          @total_profit = total_profit
        end

        # @param total_profit [Numeric, nil]
        # @return [CultivationPlanRestAdjustPlanSummary]
        def with_total_profit(total_profit)
          self.class.new(
            id: id,
            field_cultivations_count: field_cultivations_count,
            total_profit: total_profit
          )
        end

        # @return [Hash]
        def to_h
          { id: id, field_cultivations_count: field_cultivations_count, total_profit: total_profit }.compact
        end
      end
    end
  end
end
