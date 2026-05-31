# frozen_string_literal: true

module Adapters
  module InternalJobs
    module Gateways
      class SchedulerWeatherFarmListActiveRecordGateway
        include Domain::InternalJobs::Gateways::SchedulerWeatherFarmListGateway

        def list_reference_farms_for_weather_update
          ::Farm.reference.where.not(latitude: nil, longitude: nil).order(latitude: :desc).map do |farm|
            Domain::InternalJobs::Dtos::SchedulerWeatherFarmRow.new(
              farm_id: farm.id,
              latitude: farm.latitude,
              longitude: farm.longitude,
              latest_weather_date: nil
            )
          end
        end

        def list_user_farms_for_weather_update
          ::Farm.user_owned.where.not(weather_location_id: nil).map do |farm|
            Domain::InternalJobs::Dtos::SchedulerWeatherFarmRow.new(
              farm_id: farm.id,
              latitude: farm.latitude,
              longitude: farm.longitude,
              latest_weather_date: farm.weather_location&.latest_weather_date
            )
          end
        end
      end
    end
  end
end
