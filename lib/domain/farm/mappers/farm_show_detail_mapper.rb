# frozen_string_literal: true

module Domain
  module Farm
    module Mappers
      module FarmShowDetailMapper
        module_function

        # @param snapshot [Dtos::FarmShowDetailSnapshot]
        # @return [Domain::Farm::Dtos::FarmDetailOutput]
        def from_snapshot(snapshot)
          farm_entity = farm_entity_from_snapshot(snapshot.farm)
          field_entities = snapshot.fields.map { |field_row| field_entity_from_snapshot(field_row) }
          Dtos::FarmDetailOutput.new(farm: farm_entity, fields: field_entities)
        end

        def farm_entity_from_snapshot(wire)
          Entities::FarmEntity.new(
            id: wire.id,
            name: wire.name,
            latitude: wire.latitude,
            longitude: wire.longitude,
            region: wire.region,
            user_id: wire.user_id,
            created_at: wire.created_at,
            updated_at: wire.updated_at,
            is_reference: wire.is_reference,
            weather_data_status: wire.weather_data_status,
            weather_data_fetched_years: wire.weather_data_fetched_years,
            weather_data_total_years: wire.weather_data_total_years,
            weather_data_last_error: wire.weather_data_last_error,
            last_broadcast_at: wire.last_broadcast_at
          )
        end

        def field_entity_from_snapshot(wire)
          Entities::FieldEntity.new(
            id: wire.id,
            name: wire.name,
            area: wire.area,
            daily_fixed_cost: wire.daily_fixed_cost,
            region: wire.region,
            farm_id: wire.farm_id,
            user_id: wire.user_id,
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end
      end
    end
  end
end
