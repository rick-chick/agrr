# frozen_string_literal: true

module Domain
  module Farm
    module Policies
      # 参照農場はアノニマスユーザー所有のみ（内在: user の anonymous フラグを Interactor が渡す）。
      module FarmReferenceOwnershipPolicy
        module_function

        # @param is_reference [Boolean]
        # @param owner_is_anonymous [Boolean] 農場の user がアノニマスか
        def reference_farm_user_valid?(is_reference:, owner_is_anonymous:)
          !is_reference || owner_is_anonymous
        end
      end
    end
  end
end
