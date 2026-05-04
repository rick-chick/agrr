# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PrivatePlanNewOutputPort
        def on_success(private_plan_new_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
