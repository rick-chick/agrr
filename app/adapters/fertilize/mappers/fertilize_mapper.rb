# frozen_string_literal: true

module Adapters
  module Fertilize
    module Mappers
      class FertilizeMapper
        def self.fertilize_entity_from_record(record)
          Domain::Fertilize::Entities::FertilizeEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            n: record.n,
            p: record.p,
            k: record.k,
            description: record.description,
            package_size: record.package_size,
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
