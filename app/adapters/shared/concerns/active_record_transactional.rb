# frozen_string_literal: true

module Adapters
  module Shared
    module Concerns
      # Gateway 内でトランザクション境界を一元化する（Interactor は AR を参照しない）。
      module ActiveRecordTransactional
        def within_transaction(requires_new: false, &block)
          ActiveRecord::Base.transaction(requires_new: requires_new, &block)
        end
      end
    end
  end
end
