# frozen_string_literal: true

module Adapters
  module Farm
    module Gateways
      class FarmMemoryGateway < Domain::Farm::Gateways::FarmGateway
        def find_by_id(id)
          farm_record = ::Farm.find_by(id: id)
          return nil unless farm_record
          
          entity_from_record(farm_record)
        end

        def find_by_user_id(user_id)
          ::Farm.where(user_id: user_id).map { |record| entity_from_record(record) }
        end

        def create(farm_data)
          farm_record = ::Farm.create!(
            user_id: farm_data[:user_id],
            name: farm_data[:name],
            latitude: farm_data[:latitude],
            longitude: farm_data[:longitude]
          )
          
          entity_from_record(farm_record)
        end

        def update(id, farm_data)
          farm_record = ::Farm.find(id)
          
          update_attributes = {}
          update_attributes[:name] = farm_data[:name] if farm_data[:name]
          update_attributes[:latitude] = farm_data[:latitude] if farm_data[:latitude]
          update_attributes[:longitude] = farm_data[:longitude] if farm_data[:longitude]
          
          farm_record.update!(update_attributes)
          
          entity_from_record(farm_record.reload)
        end

        def delete(id)
          farm_record = ::Farm.find(id)
          farm_record.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          false
        rescue ActiveRecord::InvalidForeignKey => e
          # 外部参照制約エラーの場合、より分かりやすいメッセージを返す
          if e.message.include?('cultivation_plans')
            raise StandardError, "この農場は作付け計画で使用されているため削除できません。まず作付け計画から削除してください。"
          elsif e.message.include?('fields')
            raise StandardError, "この農場には圃場が登録されているため削除できません。まず圃場を削除してください。"
          else
            raise StandardError, "この農場は他のデータで使用されているため削除できません。"
          end
        rescue ActiveRecord::DeleteRestrictionError => e
          raise StandardError, "この農場は他のデータで使用されているため削除できません。"
        end

        def exists?(id)
          ::Farm.exists?(id: id)
        end

        private

        def entity_from_record(record)
          Domain::Farm::Entities::FarmEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            latitude: record.latitude,
            longitude: record.longitude,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
