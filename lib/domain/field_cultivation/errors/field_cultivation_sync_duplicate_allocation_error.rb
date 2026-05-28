# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Errors
      class FieldCultivationSyncDuplicateAllocationError < StandardError
        attr_reader :duplicate_ids

        def initialize(duplicate_ids:)
          @duplicate_ids = duplicate_ids
          super("duplicate allocation ids: #{duplicate_ids.join(', ')}")
        end
      end
    end
  end
end
