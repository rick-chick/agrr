# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module OptimizationPlanSnapshotMapper
        module_function

        # @param rows [Domain::CultivationPlan::Dtos::OptimizationPlanReadRows]
        # @return [Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot]
        def to_snapshot(rows)
          wl_dto = weather_location_dto(rows.weather_location)
          fm_dto = farm_weather_dto(rows.farm_weather)

          Dtos::OptimizationPlanSnapshot.new(
            plan_id: rows.plan_id,
            plan_type_private: rows.plan_type_private?,
            calculated_planning_start_date: rows.calculated_planning_start_date,
            calculated_planning_end_date: rows.calculated_planning_end_date,
            prediction_target_end_date: rows.prediction_target_end_date,
            predicted_weather_data: rows.predicted_weather_data,
            total_area: rows.total_area,
            weather_location_present: rows.weather_location_present?,
            weather_location_input: wl_dto,
            farm_weather_input: fm_dto
          )
        end

        def weather_location_dto(read)
          return nil unless read

          Domain::WeatherData::Dtos::WeatherLocation.new(
            id: read.id,
            latitude: read.latitude,
            longitude: read.longitude,
            elevation: read.elevation,
            timezone: read.timezone,
            predicted_weather_data: read.predicted_weather_data
          )
        end
        private_class_method :weather_location_dto

        def farm_weather_dto(read)
          return nil unless read

          Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
            id: read.id,
            weather_location_id: read.weather_location_id,
            predicted_weather_data: read.predicted_weather_data
          )
        end
        private_class_method :farm_weather_dto
      end
    end
  end
end
