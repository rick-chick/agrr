# frozen_string_literal: true

module Adapters
  module WeatherData
    module Mappers
      # Plan + preloaded farm / weather_location → domain DTO（業務判断なし）。
      module WeatherPredictionTargetsMapper
        module_function

        # @param plan [::CultivationPlan] farm + weather_location preload 済み
        # @return [Domain::WeatherData::Dtos::WeatherPredictionTargets]
        def from_plan(plan)
          farm = plan.farm
          Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
            weather_location: WeatherLocationMapper.weather_location_dto_from_record(farm.weather_location),
            farm: FarmWeatherPredictionMapper.farm_weather_prediction_dto_from_record(farm)
          )
        end
      end
    end
  end
end
