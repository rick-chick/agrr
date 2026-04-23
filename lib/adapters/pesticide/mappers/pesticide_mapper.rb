# frozen_string_literal: true

module Adapters
  module Pesticide
    module Mappers
      class PesticideMapper
        def self.pesticide_entity_from_record(record)
          Domain::Pesticide::Entities::PesticideEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            active_ingredient: record.active_ingredient,
            description: record.description,
            crop_id: record.crop_id,
            pest_id: record.pest_id,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
