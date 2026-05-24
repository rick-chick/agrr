# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      # EntryScheduleOptimizeInteractor が optimize_period 失敗を Result に写すためのドメイン例外
      class EntryScheduleOptimizationError < StandardError
        attr_reader :error_key

        def initialize(error_key, message = nil)
          @error_key = error_key
          super(message || error_key.to_s)
        end
      end
    end
  end
end
