# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CultivationPlanPlanCropGateway#create_for_plan 用の永続化属性。
      class CultivationPlanPlanCropCreateAttrs
        attr_reader :plan_id, :crop_id, :name, :variety, :area_per_unit, :revenue_per_area

        def initialize(plan_id:, crop_id:, name:, variety: nil, area_per_unit: nil, revenue_per_area: nil)
          @plan_id = plan_id
          @crop_id = crop_id
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
        end
      end
    end
  end
end
