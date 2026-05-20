# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr current_allocation の optimization_result ブロック。
      class AdjustWithDbWeatherOptimizationResultSnapshot
        attr_reader :optimization_id, :total_cost, :total_revenue, :total_profit, :field_schedules

        def initialize(optimization_id:, total_cost:, total_revenue:, total_profit:, field_schedules:)
          @optimization_id = optimization_id
          @total_cost = total_cost
          @total_revenue = total_revenue
          @total_profit = total_profit
          @field_schedules = field_schedules.freeze
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherOptimizationResultSnapshot]
        def self.from_hash(h)
          sym = Domain::Shared.symbolize_keys(h.to_hash)
          schedules = Array(sym[:field_schedules]).map { |fs| AdjustWithDbWeatherFieldScheduleSnapshot.from_hash(fs) }
          new(
            optimization_id: sym.fetch(:optimization_id),
            total_cost: sym.fetch(:total_cost),
            total_revenue: sym.fetch(:total_revenue),
            total_profit: sym.fetch(:total_profit),
            field_schedules: schedules
          )
        end
      end
    end
  end
end
