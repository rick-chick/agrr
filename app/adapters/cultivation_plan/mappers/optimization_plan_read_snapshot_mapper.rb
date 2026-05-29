# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module OptimizationPlanReadSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        # @param plan [::CultivationPlan] includes farm: :weather_location 推奨
        # @return [Dtos::OptimizationPlanSnapshot]
        def from_cultivation_plan(plan)
          wl = plan.farm&.weather_location
          farm = plan.farm
          Domain::CultivationPlan::Mappers::OptimizationPlanSnapshotMapper.to_snapshot(
            plan_id: plan.id,
            plan_type_private: plan.plan_type == "private",
            calculated_planning_start_date: plan.calculated_planning_start_date,
            calculated_planning_end_date: plan.calculated_planning_end_date,
            prediction_target_end_date: plan.prediction_target_end_date,
            predicted_weather_data: plan.predicted_weather_data,
            total_area: plan.total_area,
            weather_location_present: !wl.nil?,
            weather_location: wl && weather_location_dto(wl),
            farm_weather: farm && farm_weather_dto(farm)
          )
        end

        def weather_location_dto(weather_location)
          Domain::WeatherData::Dtos::WeatherLocation.new(
            id: weather_location.id,
            latitude: weather_location.latitude,
            longitude: weather_location.longitude,
            elevation: weather_location.elevation,
            timezone: weather_location.timezone,
            predicted_weather_data: weather_location.predicted_weather_data
          )
        end
        private_class_method :weather_location_dto

        def farm_weather_dto(farm)
          Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
            id: farm.id,
            weather_location_id: farm.weather_location_id,
            predicted_weather_data: farm.predicted_weather_data
          )
        end
        private_class_method :farm_weather_dto
      end
    end
  end
end
