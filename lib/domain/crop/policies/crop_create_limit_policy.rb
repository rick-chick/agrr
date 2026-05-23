# frozen_string_literal: true

module Domain
  module Crop
    module Policies
      # ユーザー所有の非参照作物は 20 件まで（ARCHITECTURE.md Resource Limits）。
      module CropCreateLimitPolicy
        MAX_NON_REFERENCE_CROPS_PER_USER = 20

        module_function

        # @param existing_non_reference_count [Integer] 永続化前の件数
        # @param is_reference [Boolean]
        # @return [Boolean]
        def limit_exceeded?(existing_non_reference_count:, is_reference: false)
          return false if is_reference

          existing_non_reference_count >= MAX_NON_REFERENCE_CROPS_PER_USER
        end
      end
    end
  end
end
