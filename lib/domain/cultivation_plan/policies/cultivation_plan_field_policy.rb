# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # 圃場追加・削除の純関数判定（Gateway / AR 非依存）。
      module CultivationPlanFieldPolicy
        module_function

        # @param field_area [Numeric, nil]
        def invalid_field_area?(field_area:)
          field_area.to_f <= 0
        end

        # @param existing_field_count [Integer]
        def max_fields_reached?(existing_field_count:)
          existing_field_count >= FieldsAllocation::MAX_FIELDS
        end

        # @param existing_field_count [Integer]
        def cannot_remove_last_field?(existing_field_count:)
          existing_field_count <= 1
        end

        # @param cultivation_count [Integer]
        def cannot_remove_with_cultivations?(cultivation_count:)
          cultivation_count.to_i.positive?
        end
      end
    end
  end
end
