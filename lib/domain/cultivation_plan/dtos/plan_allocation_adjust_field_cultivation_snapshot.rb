# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust: 1 作付の読取スナップショット（AR 生値 → domain が正規化）。
      class PlanAllocationAdjustFieldCultivationSnapshot
        attr_reader :field_cultivation_id,
                    :field_id,
                    :crop_id,
                    :crop_name,
                    :variety,
                    :area,
                    :start_date,
                    :completion_date,
                    :stored_cultivation_days,
                    :crop_stage_count,
                    :estimated_cost,
                    :optimization_result

        def initialize(
          field_cultivation_id:,
          field_id:,
          crop_id:,
          crop_name:,
          variety:,
          area:,
          start_date:,
          completion_date:,
          stored_cultivation_days:,
          crop_stage_count:,
          estimated_cost:,
          optimization_result:
        )
          @field_cultivation_id = field_cultivation_id
          @field_id = field_id
          @crop_id = crop_id
          @crop_name = crop_name
          @variety = variety
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @stored_cultivation_days = stored_cultivation_days
          @crop_stage_count = crop_stage_count
          @estimated_cost = estimated_cost
          @optimization_result = optimization_result
          freeze
        end
      end
    end
  end
end
