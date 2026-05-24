# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class RecordFarmWeatherBlockCompletedInteractor
        def initialize(farm_gateway:, farm_refresh_broadcast_port: nil)
          @farm_gateway = farm_gateway
          @farm_refresh_broadcast_port = farm_refresh_broadcast_port
        end

        def call(input_dto)
          farm = @farm_gateway.find_by_id(input_dto.farm_id, include_weather_data_fields: true)
          attrs, throttle_ok = Calculators::FarmWeatherProgressCalculator.next_after_block(
            fetched: farm.weather_data_fetched_years,
            total: farm.weather_data_total_years,
            last_broadcast_at: farm.last_broadcast_at,
            current_time: input_dto.current_time
          )
          return nil if attrs.empty?

          updated = @farm_gateway.update_weather_progress(input_dto.farm_id, attrs)
          broadcast_if_needed(input_dto.farm_id, updated, throttle_ok)
          updated
        end

        private

        def broadcast_if_needed(farm_id, farm_entity, throttle_ok)
          return unless @farm_refresh_broadcast_port && throttle_ok

          payload = {
            id: farm_entity.id,
            weather_data_status: farm_entity.weather_data_status,
            weather_data_progress: farm_entity.weather_data_progress,
            weather_data_fetched_years: farm_entity.weather_data_fetched_years,
            weather_data_total_years: farm_entity.weather_data_total_years
          }
          @farm_refresh_broadcast_port.broadcast_farm_weather_progress(farm_id: farm_id, payload: payload)
        end
      end
    end
  end
end
