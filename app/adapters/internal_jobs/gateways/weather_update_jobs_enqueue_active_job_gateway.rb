# frozen_string_literal: true

module Adapters
  module InternalJobs
    module Gateways
      class WeatherUpdateJobsEnqueueActiveJobGateway
        include Domain::InternalJobs::Gateways::WeatherUpdateJobsEnqueueGateway

        def initialize(logger:)
          @logger = logger
        end

        def enqueue_weather_update_jobs
          UpdateReferenceWeatherDataJob.perform_later
          UpdateUserFarmsWeatherDataJob.perform_later
          EnqueueWeatherUpdateJobsResult.success
        rescue ActiveJob::EnqueueError, ActiveRecord::ActiveRecordError => e
          @logger.error "❌ [Scheduler] Failed to trigger weather update: #{e.message}"
          @logger.error "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
          EnqueueWeatherUpdateJobsResult.failure(e.message)
        end
      end
    end
  end
end
