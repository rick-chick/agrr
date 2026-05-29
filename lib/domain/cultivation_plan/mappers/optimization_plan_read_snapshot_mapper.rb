# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module OptimizationPlanReadSnapshotMapper
        module_function

        def load_snapshot(read_gateway:, plan_id:)
          core = read_gateway.find_optimization_plan_core_snapshot_by_plan_id(plan_id: plan_id)
          weather_location = read_gateway.find_optimization_weather_location_by_plan_id(plan_id: plan_id)
          farm_weather = read_gateway.find_optimization_farm_weather_by_plan_id(plan_id: plan_id)

          OptimizationPlanSnapshotMapper.to_snapshot(
            plan_id: core.plan_id,
            plan_type_private: core.plan_type_private,
            calculated_planning_start_date: core.calculated_planning_start_date,
            calculated_planning_end_date: core.calculated_planning_end_date,
            prediction_target_end_date: core.prediction_target_end_date,
            predicted_weather_data: core.predicted_weather_data,
            total_area: core.total_area,
            weather_location_present: core.weather_location_present,
            weather_location: weather_location,
            farm_weather: farm_weather
          )
        end
      end
    end
  end
end
