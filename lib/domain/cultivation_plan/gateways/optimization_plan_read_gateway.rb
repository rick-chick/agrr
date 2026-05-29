# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class OptimizationPlanReadGateway
        PlanCore = Dtos::OptimizationPlanReadPlanCoreSnapshot

        def find_optimization_plan_core_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def find_optimization_weather_location_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def find_optimization_farm_weather_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
