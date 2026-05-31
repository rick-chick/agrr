# frozen_string_literal: true

module Domain
  module InternalJobs
    module Interactors
      # Replaces `UpdateReferenceWeatherDataJob` + `UpdateUserFarmsWeatherDataJob` enqueue logic.
      class SchedulerWeatherBatchEnqueueInteractor
        def initialize(list_gateway:, schedule_port:, clock:)
          @list_gateway = list_gateway
          @schedule_port = schedule_port
          @clock = clock
        end

        def call
          ref_range = WeatherData::Policies::SchedulerReferenceFarmFetchWindowPolicy.fetch_range(clock: @clock)
          if ref_range
            @list_gateway.list_reference_farms_for_weather_update.each_with_index do |farm, index|
              @schedule_port.schedule_fetch(
                farm_id: farm.farm_id,
                latitude: farm.latitude,
                longitude: farm.longitude,
                start_date: ref_range[:start_date],
                end_date: ref_range[:end_date],
                delay_secs: index
              )
            end
          end

          @list_gateway.list_user_farms_for_weather_update.each_with_index do |farm, index|
            range = WeatherData::Policies::SchedulerUserFarmFetchWindowPolicy.fetch_range(
              latest_weather_date: farm.latest_weather_date,
              clock: @clock
            )
            next unless range

            @schedule_port.schedule_fetch(
              farm_id: farm.farm_id,
              latitude: farm.latitude,
              longitude: farm.longitude,
              start_date: range[:start_date],
              end_date: range[:end_date],
              delay_secs: index
            )
          end

          @schedule_port.flush
        end
      end
    end
  end
end
