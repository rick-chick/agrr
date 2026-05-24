# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      # field / crop / plan_crop 解決失敗、日付パース失敗（保存フェーズ）。
      class AdjustResultSaveReferenceError < StandardError
        KIND_FIELD_MISSING = :field_missing
        KIND_CROP_MISSING = :crop_missing
        KIND_PLAN_CROP_MISSING = :plan_crop_missing
        KIND_START_DATE_INVALID = :start_date_invalid
        KIND_COMPLETION_DATE_INVALID = :completion_date_invalid

        attr_reader :kind, :field_id, :crop_id, :allocation_id, :raw_value

        def initialize(kind:, message:, field_id: nil, crop_id: nil, allocation_id: nil, raw_value: nil)
          @kind = kind
          @field_id = field_id
          @crop_id = crop_id
          @allocation_id = allocation_id
          @raw_value = raw_value
          super(message)
        end
      end
    end
  end
end
