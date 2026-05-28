# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期前の計画スナップショット（参照解決・差分計算用）。
      class FieldCultivationSyncPlanSnapshot
        attr_reader :plan_id,
                    :plan_fields_by_id,
                    :plan_crops_by_crop_id,
                    :existing_field_cultivation_ids

        def initialize(plan_id:, plan_fields_by_id:, plan_crops_by_crop_id:, existing_field_cultivation_ids:)
          @plan_id = plan_id
          @plan_fields_by_id = plan_fields_by_id.freeze
          @plan_crops_by_crop_id = plan_crops_by_crop_id.freeze
          @existing_field_cultivation_ids = existing_field_cultivation_ids.freeze
          freeze
        end
      end
    end
  end
end
