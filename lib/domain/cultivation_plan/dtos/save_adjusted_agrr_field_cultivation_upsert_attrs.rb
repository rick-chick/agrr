# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class SaveAdjustedAgrrFieldCultivationUpsertAttrs
        attr_reader :field_cultivation_id,
                    :cultivation_plan_field_id,
                    :cultivation_plan_crop_id,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :area,
                    :estimated_cost,
                    :optimization_result

        def initialize(
          field_cultivation_id:,
          cultivation_plan_field_id:,
          cultivation_plan_crop_id:,
          start_date:,
          completion_date:,
          cultivation_days:,
          area:,
          estimated_cost:,
          optimization_result:
        )
          @field_cultivation_id = field_cultivation_id
          @cultivation_plan_field_id = cultivation_plan_field_id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @area = area
          @estimated_cost = estimated_cost
          @optimization_result = optimization_result.freeze
          freeze
        end
      end
    end
  end
end
