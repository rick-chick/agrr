# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestMemoryGateway < Domain::Pest::Gateways::PestGateway
        def find_by_id(id)
          record = ::Pest.find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end
        
        def find_all_reference
          ::Pest.where(is_reference: true).map { |record| entity_from_record(record) }
        end
        
        def create(pest_data)
          # AGRR Gatewayからのデータは文字列キー、controllerからのデータはシンボルキー
          normalized_data = pest_data.stringify_keys
          
          record = ::Pest.new(
            name: normalized_data['name'],
            name_scientific: normalized_data['name_scientific'],
            family: normalized_data['family'],
            order: normalized_data['order'],
            description: normalized_data['description'],
            occurrence_season: normalized_data['occurrence_season'],
            is_reference: normalized_data.fetch('is_reference', false),
            user_id: normalized_data['user_id']
          )
          
          unless record.save
            error_message = record.errors.full_messages.join(', ')
            raise StandardError, error_message
          end
          
          # 温度プロファイルを作成
          if normalized_data['temperature_profile']
            temp_profile = record.build_pest_temperature_profile(
              base_temperature: normalized_data['temperature_profile']['base_temperature'],
              max_temperature: normalized_data['temperature_profile']['max_temperature']
            )
            temp_profile.save!
          end
          
          # 熱量要件を作成
          if normalized_data['thermal_requirement']
            thermal_req = record.build_pest_thermal_requirement(
              required_gdd: normalized_data['thermal_requirement']['required_gdd'],
              first_generation_gdd: normalized_data['thermal_requirement']['first_generation_gdd']
            )
            thermal_req.save!
          end
          
          # 防除方法を作成
          if normalized_data['control_methods'].is_a?(Array)
            normalized_data['control_methods'].each do |method_data|
              record.pest_control_methods.create!(
                method_type: method_data['method_type'],
                method_name: method_data['method_name'],
                description: method_data['description'],
                timing_hint: method_data['timing_hint']
              )
            end
          end
          
          entity_from_record(record.reload)
        end
        
        def update(id, pest_data)
          record = ::Pest.find(id)
          update_attributes = {}
          
          # シンボルキーと文字列キーの両方に対応
          normalized_data = pest_data.is_a?(Hash) ? pest_data.stringify_keys : pest_data
          
          update_attributes[:name] = normalized_data['name'] if normalized_data.key?('name')
          update_attributes[:name_scientific] = normalized_data['name_scientific'] if normalized_data.key?('name_scientific')
          update_attributes[:family] = normalized_data['family'] if normalized_data.key?('family')
          update_attributes[:order] = normalized_data['order'] if normalized_data.key?('order')
          update_attributes[:description] = normalized_data['description'] if normalized_data.key?('description')
          update_attributes[:occurrence_season] = normalized_data['occurrence_season'] if normalized_data.key?('occurrence_season')
          
          record.update!(update_attributes)
          
          # 温度プロファイルを更新
          if normalized_data['temperature_profile']
            if record.pest_temperature_profile
              record.pest_temperature_profile.update!(
                base_temperature: normalized_data['temperature_profile']['base_temperature'],
                max_temperature: normalized_data['temperature_profile']['max_temperature']
              )
            else
              record.create_pest_temperature_profile!(
                base_temperature: normalized_data['temperature_profile']['base_temperature'],
                max_temperature: normalized_data['temperature_profile']['max_temperature']
              )
            end
          end
          
          # 熱量要件を更新
          if normalized_data['thermal_requirement']
            if record.pest_thermal_requirement
              record.pest_thermal_requirement.update!(
                required_gdd: normalized_data['thermal_requirement']['required_gdd'],
                first_generation_gdd: normalized_data['thermal_requirement']['first_generation_gdd']
              )
            else
              record.create_pest_thermal_requirement!(
                required_gdd: normalized_data['thermal_requirement']['required_gdd'],
                first_generation_gdd: normalized_data['thermal_requirement']['first_generation_gdd']
              )
            end
          end
          
          # 既存の防除方法を削除して新しい防除方法を作成
          if normalized_data['control_methods']
            record.pest_control_methods.destroy_all
            normalized_data['control_methods'].each do |method_data|
              record.pest_control_methods.create!(
                method_type: method_data['method_type'],
                method_name: method_data['method_name'],
                description: method_data['description'],
                timing_hint: method_data['timing_hint']
              )
            end
          end
          
          entity_from_record(record.reload)
        end
        
        def delete(id)
          record = ::Pest.find(id)
          record.destroy!
          true
        rescue ActiveRecord::RecordNotFound
          false
        rescue ActiveRecord::InvalidForeignKey => e
          # 外部参照制約エラーの場合、より分かりやすいメッセージを返す
          if e.message.include?('crop_pests')
            raise StandardError, "この害虫は作物害虫情報で使用されているため削除できません。"
          else
            raise StandardError, "この害虫は他のデータで使用されているため削除できません。"
          end
        rescue ActiveRecord::DeleteRestrictionError => e
          raise StandardError, "この害虫は他のデータで使用されているため削除できません。"
        end
        
        def exists?(id)
          ::Pest.exists?(id)
        end
        
        private
        
        def entity_from_record(record)
          Domain::Pest::Entities::PestEntity.new(
            id: record.id,
            name: record.name,
            name_scientific: record.name_scientific,
            family: record.family,
            order: record.order,
            description: record.description,
            occurrence_season: record.occurrence_season,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end




