# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # 気象ロケーションの実測 1 日分（AdjustHistoricalPredictionMapper の rows 要素）。
      class HistoricalWeatherObservation
        attr_reader :date,
                    :temperature_max,
                    :temperature_min,
                    :temperature_mean,
                    :precipitation,
                    :sunshine_hours,
                    :wind_speed,
                    :weather_code

        def initialize(
          date:,
          temperature_max:,
          temperature_min:,
          temperature_mean: nil,
          precipitation: nil,
          sunshine_hours: nil,
          wind_speed: nil,
          weather_code: nil
        )
          @date = date
          @temperature_max = temperature_max
          @temperature_min = temperature_min
          @temperature_mean = temperature_mean
          @precipitation = precipitation
          @sunshine_hours = sunshine_hours
          @wind_speed = wind_speed
          @weather_code = weather_code
          freeze
        end

        def [](key)
          case key
          when :date, "date" then @date
          when :temperature_max, "temperature_max" then @temperature_max
          when :temperature_min, "temperature_min" then @temperature_min
          when :temperature_mean, "temperature_mean" then @temperature_mean
          when :precipitation, "precipitation" then @precipitation
          when :sunshine_hours, "sunshine_hours" then @sunshine_hours
          when :wind_speed, "wind_speed" then @wind_speed
          when :weather_code, "weather_code" then @weather_code
          else nil
          end
        end
      end
    end
  end
end
