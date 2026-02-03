# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class CultivationPlanDestroyInputPort
        def call(plan_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
