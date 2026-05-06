# frozen_string_literal: true

module Domain
  module InternalJobs
    module Gateways
      # Scheduler 経由で天気関連ジョブを投入する（Adapter が ActiveJob を呼ぶ）。
      module WeatherUpdateJobsEnqueueGateway
        EnqueueWeatherUpdateJobsResult = Struct.new(:kind, :error_message, keyword_init: true) do
          def self.success
            new(kind: :success)
          end

          def self.failure(message)
            new(kind: :failure, error_message: message.to_s)
          end
        end

        def enqueue_weather_update_jobs
          raise NotImplementedError, "#{self.class} must implement enqueue_weather_update_jobs"
        end
      end
    end
  end
end
