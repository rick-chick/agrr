# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestMemoryGateway < Domain::Pest::Gateways::PestGateway
        def list(scope = nil)
          query = scope || ::Pest.all
          query.map { |record| Domain::Pest::Entities::PestEntity.from_model(record) }
        end

        def find_by_id(pest_id)
          pest = ::Pest.find(pest_id)
          Domain::Pest::Entities::PestEntity.from_model(pest)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Pest not found'
        end

        def create(create_input_dto)
          pest = ::Pest.new(
            name: create_input_dto.name,
            name_scientific: create_input_dto.name_scientific,
            family: create_input_dto.family,
            order: create_input_dto.order,
            description: create_input_dto.description,
            occurrence_season: create_input_dto.occurrence_season,
            region: create_input_dto.region
          )
          raise StandardError, pest.errors.full_messages.join(', ') unless pest.save

          Domain::Pest::Entities::PestEntity.from_model(pest)
        end

        def update(pest_id, update_input_dto)
          pest = ::Pest.find(pest_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:name_scientific] = update_input_dto.name_scientific if !update_input_dto.name_scientific.nil?
          attrs[:family] = update_input_dto.family if !update_input_dto.family.nil?
          attrs[:order] = update_input_dto.order if !update_input_dto.order.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:occurrence_season] = update_input_dto.occurrence_season if !update_input_dto.occurrence_season.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pest.update(attrs)
          raise StandardError, pest.errors.full_messages.join(', ') if pest.errors.any?

          Domain::Pest::Entities::PestEntity.from_model(pest.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Pest not found'
        end
      end
    end
  end
end
