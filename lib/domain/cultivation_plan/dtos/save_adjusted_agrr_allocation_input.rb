# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # `SaveAdjustedAgrrResultGateway` が field_schedule の allocation を保存するときに読む 1 行分。
      class SaveAdjustedAgrrAllocationInput
        attr_reader :allocation_id,
                    :external_allocation_id,
                    :crop_id,
                    :start_date,
                    :completion_date,
                    :area_used,
                    :area,
                    :total_cost,
                    :cost,
                    :expected_revenue,
                    :revenue,
                    :profit,
                    :accumulated_gdd

        def initialize(
          allocation_id: nil,
          external_allocation_id: nil,
          crop_id:,
          start_date:,
          completion_date:,
          area_used: nil,
          area: nil,
          total_cost: nil,
          cost: nil,
          expected_revenue: nil,
          revenue: nil,
          profit: nil,
          accumulated_gdd: nil
        )
          @allocation_id = allocation_id
          @external_allocation_id = external_allocation_id
          @crop_id = crop_id
          @start_date = start_date
          @completion_date = completion_date
          @area_used = area_used
          @area = area
          @total_cost = total_cost
          @cost = cost
          @expected_revenue = expected_revenue
          @revenue = revenue
          @profit = profit
          @accumulated_gdd = accumulated_gdd
        end

        # @param alloc [Hash]
        # @return [SaveAdjustedAgrrAllocationInput]
        def self.from_hash(alloc)
          alloc = alloc.to_h if alloc.respond_to?(:to_h)
          new(
            allocation_id: SaveAdjustedAgrrHashPick.pick(alloc, :allocation_id),
            external_allocation_id: SaveAdjustedAgrrHashPick.pick(alloc, :id),
            crop_id: SaveAdjustedAgrrHashPick.pick(alloc, :crop_id).to_s,
            start_date: SaveAdjustedAgrrHashPick.pick(alloc, :start_date),
            completion_date: SaveAdjustedAgrrHashPick.pick(alloc, :completion_date),
            area_used: SaveAdjustedAgrrHashPick.pick(alloc, :area_used),
            area: SaveAdjustedAgrrHashPick.pick(alloc, :area),
            total_cost: SaveAdjustedAgrrHashPick.pick(alloc, :total_cost),
            cost: SaveAdjustedAgrrHashPick.pick(alloc, :cost),
            expected_revenue: SaveAdjustedAgrrHashPick.pick(alloc, :expected_revenue),
            revenue: SaveAdjustedAgrrHashPick.pick(alloc, :revenue),
            profit: SaveAdjustedAgrrHashPick.pick(alloc, :profit),
            accumulated_gdd: SaveAdjustedAgrrHashPick.pick(alloc, :accumulated_gdd)
          )
        end

        # アダプターが duplicate 検査や FieldCultivation id 解決に使う生の識別子
        # @return [Object, nil]
        def resolved_allocation_raw
          allocation_id.nil? ? external_allocation_id : allocation_id
        end
      end
    end
  end
end
