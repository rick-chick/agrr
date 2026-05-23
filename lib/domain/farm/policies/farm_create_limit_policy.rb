# frozen_string_literal: true

module Domain
  module Farm
    module Policies
      # ユーザー所有の非参照農場は 4 件まで（ARCHITECTURE.md Resource Limits）。
      module FarmCreateLimitPolicy
        MAX_NON_REFERENCE_FARMS_PER_USER = 4

        module_function

        # @param existing_non_reference_count [Integer] 永続化前の件数
        # @return [Boolean]
        def limit_exceeded?(existing_non_reference_count:)
          existing_non_reference_count >= MAX_NON_REFERENCE_FARMS_PER_USER
        end
      end
    end
  end
end
