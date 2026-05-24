# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 最適化 Interactor 用の生読み取り行（OptimizationPlanSnapshotMapper が組み立てる）。
      class OptimizationPlanReadRows
        WeatherLocationRead = Struct.new(
          :id,
          :latitude,
          :longitude,
          :elevation,
          :timezone,
          :predicted_weather_data,
          keyword_init: true
        )

        FarmWeatherRead = Struct.new(
          :id,
          :weather_location_id,
          :predicted_weather_data,
          keyword_init: true
        )

        attr_reader :plan_id,
                    :plan_type,
                    :calculated_planning_start_date,
                    :calculated_planning_end_date,
                    :prediction_target_end_date,
                    :predicted_weather_data,
                    :total_area,
                    :weather_location,
                    :farm_weather

        def initialize(
          plan_id:,
          plan_type:,
          calculated_planning_start_date:,
          calculated_planning_end_date:,
          prediction_target_end_date:,
          predicted_weather_data:,
          total_area:,
          weather_location:,
          farm_weather:
        )
          @plan_id = plan_id
          @plan_type = plan_type
          @calculated_planning_start_date = calculated_planning_start_date
          @calculated_planning_end_date = calculated_planning_end_date
          @prediction_target_end_date = prediction_target_end_date
          @predicted_weather_data = predicted_weather_data
          @total_area = total_area
          @weather_location = weather_location
          @farm_weather = farm_weather
        end

        def plan_type_private?
          plan_type == "private"
        end

        def weather_location_present?
          !weather_location.nil?
        end
      end
    end
  end
end
