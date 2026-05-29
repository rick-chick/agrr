# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      module PlanFarmWeatherPreload
        INCLUDES = { farm: :weather_location }.freeze

        module_function

        # @param plan_id [Integer, String]
        # @return [::CultivationPlan]
        # @raise [ActiveRecord::RecordNotFound]
        def find!(plan_id:)
          ::CultivationPlan.includes(INCLUDES).find(plan_id)
        end
      end
    end
  end
end
