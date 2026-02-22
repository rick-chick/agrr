# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      WeatherDataDto = Struct.new(
        :date,
        :temperature_max,
        :temperature_min,
        :temperature_mean,
        :precipitation,
        :sunshine_hours,
        :wind_speed,
        :weather_code,
        keyword_init: true
      ) do
        def self.from_attrs(attrs)
          new(
            date: attrs[:date],
            temperature_max: attrs[:temperature_max],
            temperature_min: attrs[:temperature_min],
            temperature_mean: attrs[:temperature_mean],
            precipitation: attrs[:precipitation],
            sunshine_hours: attrs[:sunshine_hours],
            wind_speed: attrs[:wind_speed],
            weather_code: attrs[:weather_code]
          )
        end

        def initialize(**args)
          super
          freeze
        end
      end
    end
  end
end
