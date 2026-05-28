# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust: agrr current allocation 向けの正規化済み作付スナップショット。
      class PlanAllocationAdjustFieldCultivationAllocationSnapshot
        attr_reader :field_cultivation_id,
                    :field_id,
                    :crop_id,
                    :crop_name,
                    :variety,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :revenue,
                    :accumulated_gdd,
                    :has_growth_stages

        def initialize(
          field_cultivation_id:,
          field_id:,
          crop_id:,
          crop_name:,
          variety:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          revenue:,
          accumulated_gdd:,
          has_growth_stages:
        )
          @field_cultivation_id = field_cultivation_id
          @field_id = field_id
          @crop_id = crop_id.to_s
          @crop_name = crop_name
          @variety = variety
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @revenue = revenue
          @accumulated_gdd = accumulated_gdd
          @has_growth_stages = has_growth_stages
          freeze
        end
      end
    end
  end
end
