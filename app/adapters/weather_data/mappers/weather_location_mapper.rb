# frozen_string_literal: true

module Adapters
  module WeatherData
    module Mappers
      module WeatherLocationMapper
        module_function

        def weather_location_dto_from_record(location)
          return nil if location.nil?

          Domain::WeatherData::Dtos::WeatherLocation.new(
            id: location.id,
            latitude: location.latitude,
            longitude: location.longitude,
            elevation: location.elevation,
            timezone: location.timezone,
            predicted_weather_data: location.predicted_weather_data
          )
        end
      end
    end
  end
end
