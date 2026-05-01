# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Entities
      class FieldCultivationEntity
        attr_reader :id, :cultivation_plan_id, :cultivation_plan_field_id, :cultivation_plan_crop_id,
                    :field_id, :area, :start_date, :status, :created_at, :updated_at

        def initialize(
          id:,
          cultivation_plan_id:,
          cultivation_plan_field_id:,
          cultivation_plan_crop_id:,
          field_id: nil,
          area:,
          start_date: nil,
          status:,
          created_at: nil,
          updated_at: nil
        )
          @id = id
          @cultivation_plan_id = cultivation_plan_id
          @cultivation_plan_field_id = cultivation_plan_field_id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @field_id = field_id
          @area = area
          @start_date = start_date
          @status = status
          @created_at = created_at
          @updated_at = updated_at
        end
      end
    end
  end
end
