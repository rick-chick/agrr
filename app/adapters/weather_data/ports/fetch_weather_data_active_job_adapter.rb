# frozen_string_literal: true

module Adapters
  module WeatherData
    module Ports
      class FetchWeatherDataActiveJobAdapter
        include Domain::Shared::Ports::FetchWeatherDataEnqueuePort

        def enqueue_farm_weather_fetch(farm_id:, latitude:, longitude:, blocks:)
          blocks.each_with_index do |block, index|
            FetchWeatherDataJob.set(wait: index * 1.0.seconds).perform_later(
              farm_id: farm_id,
              latitude: latitude,
              longitude: longitude,
              start_date: block[:start_date],
              end_date: block[:end_date]
            )
          end
        end
      end
    end
  end
end
