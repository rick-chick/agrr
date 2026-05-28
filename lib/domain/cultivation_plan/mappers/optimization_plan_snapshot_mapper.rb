# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module OptimizationPlanSnapshotMapper
        module_function

        # @return [Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot]
        def to_snapshot(
          plan_id:,
          plan_type_private:,
          calculated_planning_start_date:,
          calculated_planning_end_date:,
          prediction_target_end_date:,
          predicted_weather_data:,
          total_area:,
          weather_location_present:,
          weather_location:,
          farm_weather:
        )
          Dtos::OptimizationPlanSnapshot.new(
            plan_id: plan_id,
            plan_type_private: plan_type_private,
            calculated_planning_start_date: calculated_planning_start_date,
            calculated_planning_end_date: calculated_planning_end_date,
            prediction_target_end_date: prediction_target_end_date,
            predicted_weather_data: predicted_weather_data,
            total_area: total_area,
            weather_location_present: weather_location_present,
            weather_location_input: weather_location,
            farm_weather_input: farm_weather
          )
        end
      end
    end
  end
end
