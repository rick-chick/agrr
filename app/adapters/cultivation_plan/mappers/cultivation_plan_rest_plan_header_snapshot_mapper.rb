# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanRestPlanHeaderSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        # @param plan [::CultivationPlan] includes(:farm)
        def from_plan(plan)
          Dtos::CultivationPlanRestPlanHeaderSnapshot.new(
            id: plan.id,
            user_id: plan.user_id,
            plan_year: plan.plan_year,
            plan_name: plan.plan_name,
            display_name: plan.display_name,
            plan_type: plan.plan_type,
            status: plan.status,
            total_area: plan.total_area,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            calculated_planning_start_date: plan.calculated_planning_start_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            total_profit: plan.total_profit,
            total_revenue: plan.total_revenue,
            total_cost: plan.total_cost,
            farm_display_name: plan.farm.display_name,
            farm_region: plan.farm&.region
          )
        end
      end
    end
  end
end
