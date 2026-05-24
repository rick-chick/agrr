# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanCheckOptimizationCompletionInput
        attr_reader :plan_id

        def initialize(plan_id:)
          @plan_id = plan_id
        end
      end
    end
  end
end
