# frozen_string_literal: true

module Adapters
  module InternalJobs
    module Ports
      class SchedulerWeatherFetchScheduleActiveJobAdapter
        include Domain::InternalJobs::Ports::SchedulerWeatherFetchSchedulePort

        API_INTERVAL_SECONDS = 1.0

        def initialize
          @pending = []
        end

        def schedule_fetch(farm_id:, latitude:, longitude:, start_date:, end_date:, delay_secs:)
          @pending << {
            farm_id: farm_id,
            latitude: latitude,
            longitude: longitude,
            start_date: start_date,
            end_date: end_date,
            delay_secs: delay_secs
          }
        end

        def flush
          @pending.each do |entry|
            FetchWeatherDataJob.set(wait: entry[:delay_secs] * API_INTERVAL_SECONDS.seconds).perform_later(
              farm_id: entry[:farm_id],
              latitude: entry[:latitude],
              longitude: entry[:longitude],
              start_date: entry[:start_date],
              end_date: entry[:end_date]
            )
          end
          @pending.clear
        end
      end
    end
  end
end
