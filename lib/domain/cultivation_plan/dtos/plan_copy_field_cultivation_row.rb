# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanCopyFieldCultivationRow
        attr_reader :cultivation_plan_field_id, :cultivation_plan_crop_id, :area, :status

        def initialize(cultivation_plan_field_id:, cultivation_plan_crop_id:, area:, status:)
          @cultivation_plan_field_id = cultivation_plan_field_id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @area = area
          @status = status
        end
      end
    end
  end
end
