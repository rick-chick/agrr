# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PrivatePlanOptimizingMapper
        def self.call(read_model)
          Domain::CultivationPlan::Dtos::PrivatePlanOptimizing.new(
            id: read_model.id,
            plan_year: read_model.plan_year,
            farm_display_name: read_model.farm_display_name,
            cultivation_plan_crops_count: read_model.cultivation_plan_crops_count,
            optimization_phase_message: read_model.optimization_phase_message,
            status: read_model.status
          )
        end
      end
    end
  end
end
