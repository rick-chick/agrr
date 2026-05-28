# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期後に存在すべき 1 件の field_cultivation 行（新規 or 既存更新）。
      class FieldCultivationSyncDesiredRow
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
