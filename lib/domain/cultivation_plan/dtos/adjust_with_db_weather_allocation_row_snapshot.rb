# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr current allocation 内の allocation 1 行（文字列日付は agrr ペイロード互換）。
      class AdjustWithDbWeatherAllocationRowSnapshot
        attr_reader :allocation_id, :crop_id, :crop_name, :variety, :area_used,
                    :start_date, :completion_date, :growth_days, :accumulated_gdd,
                    :total_cost, :expected_revenue, :profit

        def initialize(allocation_id:, crop_id:, crop_name:, variety:, area_used:,
                       start_date:, completion_date:, growth_days:, accumulated_gdd:,
                       total_cost:, expected_revenue:, profit:)
          @allocation_id = allocation_id
          @crop_id = crop_id.to_s
          @crop_name = crop_name
          @variety = variety
          @area_used = area_used
          @start_date = start_date
          @completion_date = completion_date
          @growth_days = growth_days
          @accumulated_gdd = accumulated_gdd
          @total_cost = total_cost
          @expected_revenue = expected_revenue
          @profit = profit
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherAllocationRowSnapshot]
        def self.from_hash(h)
          sym = Domain::Shared.symbolize_keys(h.to_hash)
          new(
            allocation_id: sym.fetch(:allocation_id),
            crop_id: sym.fetch(:crop_id),
            crop_name: sym.fetch(:crop_name),
            variety: sym[:variety],
            area_used: sym.fetch(:area_used),
            start_date: sym[:start_date],
            completion_date: sym[:completion_date],
            growth_days: sym.fetch(:growth_days),
            accumulated_gdd: sym.fetch(:accumulated_gdd),
            total_cost: sym.fetch(:total_cost),
            expected_revenue: sym.fetch(:expected_revenue),
            profit: sym.fetch(:profit)
          )
        end
      end
    end
  end
end
