# frozen_string_literal: true

module Adapters
  module WeatherData
    module Gateways
      class InternalWeatherFetchStartActiveRecordGateway
        include Domain::WeatherData::Gateways::InternalWeatherFetchStartGateway

        def start_internal_weather_data_fetch(farm_id:)
          lookup = Adapters::Shared::InternalApiFarmLookup.find_farm(farm_id)
          return StartInternalWeatherFetchResult.farm_not_found if lookup[:kind] == :not_found

          farm = lookup[:farm]

          if farm.weather_location && farm.weather_data_status == "completed"
            count = farm.weather_location.weather_data.count
            return StartInternalWeatherFetchResult.completed(
              WeatherFetchFarmSnapshot.new(
                farm_id: farm.id,
                weather_data_status: farm.weather_data_status,
                weather_data_count: count,
                total_blocks: farm.weather_data_total_years
              )
            )
          end

          farm.enqueue_weather_data_fetch

          StartInternalWeatherFetchResult.started(
            WeatherFetchFarmSnapshot.new(
              farm_id: farm.id,
              weather_data_status: farm.weather_data_status,
              weather_data_count: nil,
              total_blocks: farm.weather_data_total_years
            )
          )
        rescue ActiveRecord::RecordInvalid, ActiveJob::EnqueueError => e
          StartInternalWeatherFetchResult.failed(e.message)
        end
      end
    end
  end
end
