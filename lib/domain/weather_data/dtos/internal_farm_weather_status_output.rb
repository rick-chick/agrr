# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # GET internal/farms/:farm_id/weather_status の成功ペイロード。
      class InternalFarmWeatherStatusOutput
        attr_reader :farm_id, :status, :progress, :fetched_blocks, :total_blocks, :weather_data_count, :last_error

        def initialize(farm_id:, status:, progress:, fetched_blocks:, total_blocks:, weather_data_count:, last_error:)
          @farm_id = farm_id
          @status = status
          @progress = progress
          @fetched_blocks = fetched_blocks
          @total_blocks = total_blocks
          @weather_data_count = weather_data_count
          @last_error = last_error
        end
      end
    end
  end
end
