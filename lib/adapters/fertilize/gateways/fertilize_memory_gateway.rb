# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeMemoryGateway < Domain::Fertilize::Gateways::FertilizeGateway
        def find_by_id(id)
          record = ::Fertilize.find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end
        
        def find_all_reference
          ::Fertilize.where(is_reference: true).map { |record| entity_from_record(record) }
        end
        
        def create(fertilize_data)
          # AGRR Gatewayからのデータは文字列キー、controllerからのデータはシンボルキー
          normalized_data = fertilize_data.stringify_keys
          
          record = ::Fertilize.new(
            name: normalized_data['name'],
            n: normalized_data['n'],
            p: normalized_data['p'],
            k: normalized_data['k'],
            description: normalized_data['description'],
            usage: normalized_data['usage'],
            application_rate: normalized_data['application_rate'],
            package_size: normalized_data['package_size'],
            is_reference: normalized_data.fetch('is_reference', true)  # デフォルトは参照データ
          )
          
          unless record.save
            error_message = record.errors.full_messages.join(', ')
            raise StandardError, error_message
          end
          
          entity_from_record(record)
        end
        
        def update(id, fertilize_data)
          record = ::Fertilize.find(id)
          update_attributes = {}
          
          # シンボルキーと文字列キーの両方に対応
          normalized_data = fertilize_data.is_a?(Hash) ? fertilize_data.stringify_keys : fertilize_data
          
          update_attributes[:name] = normalized_data['name'] if normalized_data.key?('name')
          update_attributes[:n] = normalized_data['n'] if normalized_data.key?('n')
          update_attributes[:p] = normalized_data['p'] if normalized_data.key?('p')
          update_attributes[:k] = normalized_data['k'] if normalized_data.key?('k')
          update_attributes[:description] = normalized_data['description'] if normalized_data.key?('description')
          update_attributes[:usage] = normalized_data['usage'] if normalized_data.key?('usage')
          update_attributes[:application_rate] = normalized_data['application_rate'] if normalized_data.key?('application_rate')
          update_attributes[:package_size] = normalized_data['package_size'] if normalized_data.key?('package_size')
          
          record.update!(update_attributes)
          entity_from_record(record.reload)
        end
        
        def delete(id)
          record = ::Fertilize.find(id)
          record.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          false
        rescue ActiveRecord::InvalidForeignKey => e
          # 外部参照制約エラーの場合、より分かりやすいメッセージを返す
          if e.message.include?('crop_fertilizes')
            raise StandardError, "この肥料は作物肥料情報で使用されているため削除できません。"
          else
            raise StandardError, "この肥料は他のデータで使用されているため削除できません。"
          end
        rescue ActiveRecord::DeleteRestrictionError => e
          raise StandardError, "この肥料は他のデータで使用されているため削除できません。"
        end
        
        def exists?(id)
          ::Fertilize.exists?(id)
        end
        
        private
        
        def entity_from_record(record)
          Domain::Fertilize::Entities::FertilizeEntity.new(
            id: record.id,
            name: record.name,
            n: record.n,
            p: record.p,
            k: record.k,
            description: record.description,
            usage: record.usage,
            application_rate: record.application_rate,
            package_size: record.package_size,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end

