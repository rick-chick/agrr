# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationClimatePlanWeatherMapper
        module_function

        # @param source [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        # @return [Domain::WeatherData::Dtos::CultivationPlanWeather]
        def to_cultivation_plan_weather(source:)
          Domain::WeatherData::Dtos::CultivationPlanWeather.new(
            id: source.plan_id,
            prediction_target_end_date: source.prediction_target_end_date,
            calculated_planning_end_date: source.calculated_planning_end_date,
            predicted_weather_data: source.predicted_weather_data
          )
        end
      end
    end
  end
end
