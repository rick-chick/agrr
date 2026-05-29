# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module OptimizationPlanFarmWeatherSnapshotMapper
        module_function

        def from_farm(farm)
          Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
            id: farm.id,
            weather_location_id: farm.weather_location_id,
            predicted_weather_data: farm.predicted_weather_data
          )
        end
      end
    end
  end
end
