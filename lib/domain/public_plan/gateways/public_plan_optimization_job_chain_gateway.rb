# frozen_string_literal: true

module Domain
  module PublicPlan
    module Gateways
      class PublicPlanOptimizationJobChainGateway
        def enqueue_after_create!(cultivation_plan_id:, caller_label:, redirect_path: nil)
          raise NotImplementedError, "Subclasses must implement enqueue_after_create!"
        end
      end
    end
  end
end
