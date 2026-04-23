# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      # Maps persistence records to domain farm DTO/entities. Interactors do not use AR.
      class FarmMapper
        def self.farm_entity_from_record(record)
          Domain::Farm::Entities::FarmEntity.new(
            id: record.id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            region: record.region,
            user_id: record.user_id,
            created_at: record.created_at,
            updated_at: record.updated_at,
            is_reference: record.is_reference
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

        def self.detail_dto_from_farm_record(farm)
          farm_entity = farm_entity_from_record(farm)
          field_entities = farm.fields.map { |f| field_entity_from_record(f) }
          Domain::Farm::Dtos::FarmDetailOutputDto.new(farm: farm_entity, fields: field_entities)
        end
      end
    end
  end
end
