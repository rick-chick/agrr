# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr adjust の保存に必要な範囲の入力（`SaveAdjustedAgrrResultGateway#save_adjust_result!`）。
      class SaveAdjustedAgrrResultInput
        attr_reader :field_schedules,
                    :summary,
                    :total_profit,
                    :total_revenue,
                    :total_cost,
                    :optimization_time,
                    :algorithm_used,
                    :is_optimal

        def initialize(
          field_schedules:,
          summary: nil,
          total_profit: nil,
          total_revenue: nil,
          total_cost: nil,
          optimization_time: nil,
          algorithm_used: nil,
          is_optimal: nil
        )
          @field_schedules = field_schedules.freeze
          @summary = summary
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          @optimization_time = optimization_time
          @algorithm_used = algorithm_used
          @is_optimal = is_optimal
        end

        # @param result [Hash]
        # @return [SaveAdjustedAgrrResultInput]
        def self.from_agrr_adjust_result_hash(result)
          result = result.to_h if result.respond_to?(:to_h)
          raw_fs = SaveAdjustedAgrrHashPick.pick(result, :field_schedules)
          raw_fs = [] if raw_fs.nil?
          new(
            field_schedules: raw_fs.map { |fs| SaveAdjustedAgrrFieldScheduleInput.from_hash(fs) },
            summary: SaveAdjustedAgrrHashPick.pick(result, :summary),
            total_profit: SaveAdjustedAgrrHashPick.pick(result, :total_profit),
            total_revenue: SaveAdjustedAgrrHashPick.pick(result, :total_revenue),
            total_cost: SaveAdjustedAgrrHashPick.pick(result, :total_cost),
            optimization_time: SaveAdjustedAgrrHashPick.pick(result, :optimization_time),
            algorithm_used: SaveAdjustedAgrrHashPick.pick(result, :algorithm_used),
            is_optimal: SaveAdjustedAgrrHashPick.pick(result, :is_optimal)
          )
        end
      end
    end
  end
end
