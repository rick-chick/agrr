# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestCropAssociationSyncResult
        attr_reader :added, :removed

        def initialize(added:, removed:)
          @added = added
          @removed = removed
        end
      end
    end
  end
end
