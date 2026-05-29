# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustReadFieldCultivationRowSnapshot
        attr_reader :id,
                    :cultivation_plan_field_id,
                    :crop_id,
                    :crop_name,
                    :variety,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :crop_stage_count,
                    :estimated_cost,
                    :optimization_result

        def initialize(
          id:,
          cultivation_plan_field_id:,
          crop_id:,
          crop_name:,
          variety:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          crop_stage_count:,
          estimated_cost:,
          optimization_result:
        )
          @id = id
          @cultivation_plan_field_id = cultivation_plan_field_id
          @crop_id = crop_id
          @crop_name = crop_name
          @variety = variety
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @crop_stage_count = crop_stage_count
          @estimated_cost = estimated_cost
          @optimization_result = optimization_result
          freeze
        end
      end
    end
  end
end
