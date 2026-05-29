# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class OptimizationPlanReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::OptimizationPlanReadGateway
        Core = Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot

        def find_optimization_plan_core_snapshot_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          Core.new(
            plan_id: plan.id,
            plan_type_private: plan.plan_type == "private",
            calculated_planning_start_date: plan.calculated_planning_start_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            total_area: plan.total_area,
            weather_location_present: plan.farm&.weather_location.present?
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_optimization_weather_location_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          wl = plan.farm&.weather_location
          return nil unless wl

          Mappers::OptimizationPlanWeatherLocationSnapshotMapper.from_weather_location(wl)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_optimization_farm_weather_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(:farm).find(plan_id)
          farm = plan.farm
          return nil unless farm

          Mappers::OptimizationPlanFarmWeatherSnapshotMapper.from_farm(farm)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
