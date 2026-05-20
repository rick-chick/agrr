# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr field_schedule 1 要素。
      class AdjustWithDbWeatherFieldScheduleSnapshot
        attr_reader :field_id, :field_name, :total_cost, :total_revenue, :total_profit,
                    :utilization_rate, :allocations

        def initialize(field_id:, field_name:, total_cost:, total_revenue:, total_profit:,
                       utilization_rate:, allocations:)
          @field_id = field_id.to_s
          @field_name = field_name
          @total_cost = total_cost
          @total_revenue = total_revenue
          @total_profit = total_profit
          @utilization_rate = utilization_rate
          @allocations = allocations.freeze
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherFieldScheduleSnapshot]
        def self.from_hash(h)
          sym = Domain::Shared.symbolize_keys(h.to_hash)
          rows = Array(sym[:allocations]).map { |a| AdjustWithDbWeatherAllocationRowSnapshot.from_hash(a) }
          new(
            field_id: sym.fetch(:field_id),
            field_name: sym.fetch(:field_name),
            total_cost: sym.fetch(:total_cost),
            total_revenue: sym.fetch(:total_revenue),
            total_profit: sym.fetch(:total_profit),
            utilization_rate: sym.fetch(:utilization_rate),
            allocations: rows
          )
        end
      end
    end
  end
end
