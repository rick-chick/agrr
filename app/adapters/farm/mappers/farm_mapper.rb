# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      # Maps persistence records to domain farm DTO/entities. Interactors do not use AR.
      class FarmMapper
        def self.farm_entity_from_record(record, include_weather_data_fields: false)
          weather_kwargs =
            if include_weather_data_fields
              {
                weather_data_status: record.weather_data_status,
                weather_data_fetched_years: record.weather_data_fetched_years,
                weather_data_total_years: record.weather_data_total_years,
                weather_data_last_error: record.weather_data_last_error,
                last_broadcast_at: record.last_broadcast_at
              }
            else
              {}
            end

          Domain::Farm::Entities::FarmEntity.new(
            id: record.id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            region: record.region,
            user_id: record.user_id,
            created_at: record.created_at,
            updated_at: record.updated_at,
            is_reference: record.is_reference,
            **weather_kwargs
          )
        end

        def self.field_entity_from_record(record)
          Domain::Farm::Entities::FieldEntity.new(
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
