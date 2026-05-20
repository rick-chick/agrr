# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      # GET internal/farms/:farm_id/weather_data の成功ペイロード（JSON 組み立ては Presenter）。
      class InternalFarmWeatherDataListOutput
        attr_reader :farm_summary, :weather_location_summary, :weather_data_rows, :count

        def initialize(farm_summary:, weather_location_summary:, weather_data_rows:, count:)
          @farm_summary = farm_summary
          @weather_location_summary = weather_location_summary
          @weather_data_rows = weather_data_rows
          @count = count
        end
      end
    end
  end
end
