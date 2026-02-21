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
        def initialize(**args)
          super
          freeze
        end
      end
    end
  end
end
