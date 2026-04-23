# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      class AllocationNoCandidatesError < StandardError; end

      class AllocationExecutionError < StandardError; end
    end
  end
end
