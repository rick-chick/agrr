# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 計画単位同期で扱う 1 allocation 行分（agrr 非依存）。
      class FieldCultivationSyncAllocationInput
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

        # duplicate 検査や FieldCultivation id 解決に使う生の識別子
        # @return [Object, nil]
        def resolved_allocation_raw
          allocation_id.nil? ? external_allocation_id : allocation_id
        end
      end
    end
  end
end
