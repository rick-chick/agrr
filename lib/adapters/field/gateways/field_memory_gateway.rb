# frozen_string_literal: true

module Adapters
  module Field
    module Gateways
      class FieldMemoryGateway < Domain::Field::Gateways::FieldGateway
        def find_by_id(id)
          field_record = ::Field.find_by(id: id)
          return nil unless field_record
          
          entity_from_record(field_record)
        end

        def find_by_farm_id(farm_id)
          ::Field.where(farm_id: farm_id).map { |record| entity_from_record(record) }
        end

        def find_by_user_id(user_id)
          ::Field.where(user_id: user_id).map { |record| entity_from_record(record) }
        end

        def create(field_data)
          field_record = ::Field.create!(
            farm_id: field_data[:farm_id],
            user_id: field_data[:user_id],
            name: field_data[:name],
            latitude: field_data[:latitude],
            longitude: field_data[:longitude],
            description: field_data[:description]
          )
          
          entity_from_record(field_record)
        end

        def update(id, field_data)
          field_record = ::Field.find(id)
          
          update_attributes = {}
          update_attributes[:name] = field_data[:name] if field_data[:name]
          update_attributes[:latitude] = field_data[:latitude] if field_data[:latitude]
          update_attributes[:longitude] = field_data[:longitude] if field_data[:longitude]
          update_attributes[:description] = field_data[:description] if field_data.key?(:description)
          
          field_record.update!(update_attributes)
          
          entity_from_record(field_record.reload)
        end

        def delete(id)
          field_record = ::Field.find(id)
          field_record.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          false
        end

        def exists?(id)
          ::Field.exists?(id: id)
        end

        private

        def entity_from_record(record)
          Domain::Field::Entities::FieldEntity.new(
            id: record.id,
            farm_id: record.farm_id,
            user_id: record.user_id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            description: record.description,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
