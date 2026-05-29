# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      class PestMapper
        def self.pest_entity_from_record(record)
          Domain::Pest::Entities::PestEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            name_scientific: record.name_scientific,
            family: record.family,
            order: record.order,
            description: record.description,
            occurrence_season: record.occurrence_season,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        rescue ArgumentError => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

      end
    end
  end
end
