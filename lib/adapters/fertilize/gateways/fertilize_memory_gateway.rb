# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      class FertilizeMemoryGateway < Domain::Fertilize::Gateways::FertilizeGateway
        def list
          # Entity は name 必須のため、name が present なレコードのみ変換する
          ::Fertilize.where.not(name: [nil, '']).map { |record| Domain::Fertilize::Entities::FertilizeEntity.from_model(record) }
        end

        def find_by_id(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Fertilize not found'
        end

        def create(create_input_dto)
          fertilize = ::Fertilize.new(
            name: create_input_dto.name,
            n: create_input_dto.n,
            p: create_input_dto.p,
            k: create_input_dto.k,
            description: create_input_dto.description,
            package_size: create_input_dto.package_size,
            region: create_input_dto.region
          )
          raise StandardError, fertilize.errors.full_messages.join(', ') unless fertilize.save

          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize)
        end

        def update(fertilize_id, update_input_dto)
          fertilize = ::Fertilize.find(fertilize_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:n] = update_input_dto.n if !update_input_dto.n.nil?
          attrs[:p] = update_input_dto.p if !update_input_dto.p.nil?
          attrs[:k] = update_input_dto.k if !update_input_dto.k.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:package_size] = update_input_dto.package_size if !update_input_dto.package_size.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          fertilize.update(attrs)
          raise StandardError, fertilize.errors.full_messages.join(', ') if fertilize.errors.any?

          Domain::Fertilize::Entities::FertilizeEntity.from_model(fertilize.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, 'Fertilize not found'
        end

      end
    end
  end
end
