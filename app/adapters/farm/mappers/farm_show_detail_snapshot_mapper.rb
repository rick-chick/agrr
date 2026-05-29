# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      module FarmShowDetailSnapshotMapper
        Dtos = Domain::Farm::Dtos

        module_function

        def from_model(farm)
          Dtos::FarmShowDetailSnapshot.new(
            farm: farm_snapshot_from(farm),
            fields: farm.fields.map { |field| field_snapshot_from(field) }
          )
        end

        def farm_snapshot_from(record)
          Dtos::FarmShowDetailFarmSnapshot.new(
            id: record.id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            region: record.region,
            user_id: record.user_id,
            created_at: record.created_at,
            updated_at: record.updated_at,
            is_reference: record.is_reference,
            weather_data_status: record.weather_data_status,
            weather_data_fetched_years: record.weather_data_fetched_years,
            weather_data_total_years: record.weather_data_total_years,
            weather_data_last_error: record.weather_data_last_error,
            last_broadcast_at: record.last_broadcast_at
          )
        end

        def field_snapshot_from(record)
          Dtos::FarmShowDetailFieldSnapshot.new(
            id: record.id,
            name: record.name,
            area: record.area,
            daily_fixed_cost: record.daily_fixed_cost,
            region: record.region,
            farm_id: record.farm_id,
            user_id: record.user_id,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
