# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PlanListForUserOutputPort
        def on_success(plans_index_data)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
