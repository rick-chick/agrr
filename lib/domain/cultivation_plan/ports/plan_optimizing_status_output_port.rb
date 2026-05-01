# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PlanOptimizingStatusOutputPort
        def on_success(plan_optimizing_view_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
