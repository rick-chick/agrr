# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # adjust 結果保存前の計画スナップショット（永続化の参照解決用）。
      class SaveAdjustedAgrrPersistContext
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
