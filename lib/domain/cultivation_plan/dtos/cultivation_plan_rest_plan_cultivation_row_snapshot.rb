# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanRestPlanCultivationRowSnapshot
        attr_reader :id,
                    :cultivation_plan_field_id,
                    :field_display_name,
                    :cultivation_plan_crop_id,
                    :crop_display_name,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :optimization_result,
                    :status

        def initialize(
          id:,
          cultivation_plan_field_id:,
          field_display_name:,
          cultivation_plan_crop_id:,
          crop_display_name:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          optimization_result:,
          status:
        )
          @id = id
          @cultivation_plan_field_id = cultivation_plan_field_id
          @field_display_name = field_display_name
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @crop_display_name = crop_display_name
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @optimization_result = optimization_result
          @status = status
          freeze
        end
      end
    end
  end
end
