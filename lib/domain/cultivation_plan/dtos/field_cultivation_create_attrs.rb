# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CultivationPlanGateway#create_field_cultivation 用の永続化属性。
      class FieldCultivationCreateAttrs
        attr_reader :cultivation_plan_field_id,
                    :cultivation_plan_crop_id,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :status,
                    :optimization_result

        # @param optimization_result [FieldCultivationOptimizationPersist]
        def initialize(
          cultivation_plan_field_id:,
          cultivation_plan_crop_id:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          status:,
          optimization_result:
        )
          @cultivation_plan_field_id = cultivation_plan_field_id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @status = status
          @optimization_result = optimization_result
          freeze
        end

        # @return [Hash] FieldCultivation#create! に渡す属性
        def to_active_record_attributes
          {
            cultivation_plan_field_id: cultivation_plan_field_id,
            cultivation_plan_crop_id: cultivation_plan_crop_id,
            area: area,
            start_date: start_date,
            completion_date: completion_date,
            cultivation_days: cultivation_days,
            estimated_cost: estimated_cost,
            status: status,
            optimization_result: optimization_result.to_storage_hash
          }
        end
      end
    end
  end
end
