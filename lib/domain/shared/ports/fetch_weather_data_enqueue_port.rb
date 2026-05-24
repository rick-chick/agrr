# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      module FetchWeatherDataEnqueuePort
        # @param blocks [Array<Hash>] :start_date, :end_date
        def enqueue_farm_weather_fetch(farm_id:, latitude:, longitude:, blocks:)
          raise NotImplementedError, "#{self.class}#enqueue_farm_weather_fetch"
        end
      end
    end
  end
end
