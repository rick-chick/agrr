# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class StartFarmWeatherDataFetchInteractor
        def initialize(farm_gateway:, fetch_weather_data_enqueue_port:)
          @farm_gateway = farm_gateway
          @fetch_weather_data_enqueue_port = fetch_weather_data_enqueue_port
        end

        def call(input_dto)
          farm = @farm_gateway.find_by_id(input_dto.farm_id)
          return nil unless farm.has_coordinates?

          as_of = input_dto.as_of
          attrs = Calculators::FarmWeatherProgressCalculator.start_fetch_attrs(as_of: as_of)
          @farm_gateway.update_weather_progress(input_dto.farm_id, attrs)

          blocks = Calculators::FarmWeatherProgressCalculator.weather_fetch_blocks(as_of: as_of)
          @fetch_weather_data_enqueue_port.enqueue_farm_weather_fetch(
            farm_id: farm.id,
            latitude: farm.latitude,
            longitude: farm.longitude,
            blocks: blocks
          )
          farm
        end
      end
    end
  end
end
