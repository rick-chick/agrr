# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class PlanAllocationGateway
        def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          raise NotImplementedError, "Subclasses must implement allocate"
        end
      end
    end
  end
end
