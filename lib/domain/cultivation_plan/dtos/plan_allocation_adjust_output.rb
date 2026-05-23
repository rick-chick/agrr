# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustOutput
        attr_reader :message, :cultivation_plan, :skipped

        # @param message [String]
        # @param cultivation_plan [Hash, nil] plan summary for API（total_profit 含む）
        # @param skipped [Boolean]
        def initialize(message:, cultivation_plan: nil, skipped: false)
          @message = message
          @cultivation_plan = cultivation_plan
          @skipped = skipped
        end
      end
    end
  end
end
