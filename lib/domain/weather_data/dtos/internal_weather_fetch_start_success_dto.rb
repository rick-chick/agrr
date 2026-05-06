# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      class InternalWeatherFetchStartSuccessDto
        attr_reader :variant, :farm_id, :weather_data_status, :weather_data_count, :total_blocks

        VARIANT_ALREADY_COMPLETED = :already_completed
        VARIANT_FETCH_STARTED = :fetch_started

        def initialize(variant:, farm_id:, weather_data_status:, weather_data_count:, total_blocks:)
          @variant = variant
          @farm_id = farm_id
          @weather_data_status = weather_data_status
          @weather_data_count = weather_data_count
          @total_blocks = total_blocks
        end
      end
    end
  end
end
