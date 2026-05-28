# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # 同期前の計画スナップショット（参照解決・差分計算用）。
      class FieldCultivationSyncPlanSnapshot
        attr_reader :plan_id,
                    :plan_fields_by_id,
                    :plan_crop_rows,
                    :existing_field_cultivations_by_id

        # @param plan_crop_rows [Array<FieldCultivationSyncPlanCropEntry>]
        # @param existing_field_cultivations_by_id [Hash{Integer => FieldCultivationSyncExistingFieldCultivationEntry}]
        def initialize(plan_id:, plan_fields_by_id:, plan_crop_rows:, existing_field_cultivations_by_id:)
          @plan_id = plan_id
          @plan_fields_by_id = plan_fields_by_id.freeze
          @plan_crop_rows = Array(plan_crop_rows).freeze
          @existing_field_cultivations_by_id = existing_field_cultivations_by_id.freeze
          freeze
        end

        def existing_field_cultivation_ids
          existing_field_cultivations_by_id.keys
        end
      end
    end
  end
end
