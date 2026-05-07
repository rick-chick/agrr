# frozen_string_literal: true

module Adapters
  module WeatherData
    class PredictWeatherStandaloneEnqueueActiveJobAdapter
      include Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueuePort

      def initialize(logger:)
        @logger = logger
      end

      def enqueue_predict_weather_standalone(farm_id:, days:, model:, target_end_date:, cultivation_plan_id:, channel_class:)
        PredictWeatherDataJob.perform_later(
          farm_id: farm_id,
          days: days,
          model: model,
          target_end_date: target_end_date,
          cultivation_plan_id: cultivation_plan_id,
          channel_class: channel_class
        )
        Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult.success
      rescue ActiveJob::EnqueueError => e
        @logger.error "❌ Failed to queue prediction job for Farm##{farm_id}: #{e.message}"
        @logger.error e.backtrace.join("\n")
        Domain::WeatherData::Ports::PredictWeatherStandaloneEnqueueResult.failure(e.message)
      end
    end
  end
end
