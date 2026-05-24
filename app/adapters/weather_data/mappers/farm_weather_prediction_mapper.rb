# frozen_string_literal: true

module Adapters
  module WeatherData
    module Mappers
      module FarmWeatherPredictionMapper
        module_function

        def farm_weather_prediction_dto_from_record(farm)
          return nil if farm.nil?

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
