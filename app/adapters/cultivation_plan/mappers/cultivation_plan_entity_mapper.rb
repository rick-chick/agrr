# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanEntityMapper
        module_function

        def entity_from_model(plan)
          return nil if plan.nil?

          Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: plan.id,
            farm_id: plan.farm_id,
            user_id: plan.user_id,
            total_area: plan.total_area,
            plan_type: plan.plan_type,
            plan_year: plan.read_attribute(:plan_year),
            plan_name: plan.read_attribute(:plan_name),
            planning_start_date: plan.read_attribute(:planning_start_date),
            planning_end_date: plan.read_attribute(:planning_end_date),
            status: plan.status,
            optimization_phase: plan.optimization_phase,
            optimization_phase_message: plan.optimization_phase_message,
            session_id: plan.read_attribute(:session_id),
            display_name: plan.display_name,
            cultivation_plan_crops_count: plan.cultivation_plan_crops.count,
            cultivation_plan_fields_count: plan.cultivation_plan_fields.count,
            created_at: plan.created_at,
            updated_at: plan.updated_at
          )
        end
      end
    end
  end
end
