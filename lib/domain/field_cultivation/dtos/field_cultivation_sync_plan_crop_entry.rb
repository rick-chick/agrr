# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 計画に紐づく cultivation_plan_crop 1 行（同一 crop_id の重複を潰さない）。
      class FieldCultivationSyncPlanCropEntry
        attr_reader :plan_crop_id, :crop_id

        def initialize(plan_crop_id:, crop_id:)
          @plan_crop_id = plan_crop_id
          @crop_id = crop_id.to_s
          freeze
        end
      end
    end
  end
end
