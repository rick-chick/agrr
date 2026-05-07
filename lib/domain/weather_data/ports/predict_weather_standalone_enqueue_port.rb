# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      module PredictWeatherStandaloneEnqueuePort
        # @return [Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult]
        def enqueue_predict_weather_standalone(farm_id:, days:, model:, target_end_date:, cultivation_plan_id:, channel_class:)
          raise NotImplementedError, "#{self.class} must implement enqueue_predict_weather_standalone"
        end
      end
    end
  end
end
