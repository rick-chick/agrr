# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      class AdjustResultDuplicateAllocationError < StandardError
        attr_reader :duplicate_ids

        def initialize(duplicate_ids:)
          @duplicate_ids = Array(duplicate_ids).freeze
          super("duplicate allocation ids: #{@duplicate_ids.join(', ')}")
        end
      end
    end
  end
end
