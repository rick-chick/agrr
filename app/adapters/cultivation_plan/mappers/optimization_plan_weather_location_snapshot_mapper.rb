# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module OptimizationPlanWeatherLocationSnapshotMapper
        module_function

        def from_weather_location(weather_location)
          Domain::WeatherData::Dtos::WeatherLocation.new(
            id: weather_location.id,
            latitude: weather_location.latitude,
            longitude: weather_location.longitude,
            elevation: weather_location.elevation,
            timezone: weather_location.timezone,
            predicted_weather_data: weather_location.predicted_weather_data
          )
        end
      end
    end
  end
end
