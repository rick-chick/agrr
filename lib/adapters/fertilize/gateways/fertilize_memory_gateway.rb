# frozen_string_literal: true

module Adapters
  module Fertilize
    module Gateways
      # AI 作成フロー等で使う。永続化は DB（ActiveRecord）だが list のみ従来仕様を維持。
      class FertilizeMemoryGateway < FertilizeActiveRecordGateway
        # Entity 変換で name 必須のため、一覧 API では空名を除外（従来仕様）
        def list_index_for_user(user)
          fertilize_visible_scope(user).where.not(name: [ nil, "" ]).map { |record| Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(record) }
        end

        def list
          ::Fertilize.where.not(name: [ nil, "" ]).map { |record| Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(record) }
        end

        def find_by_id(fertilize_id)
          fertilize = ::Fertilize.find(fertilize_id)
          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Fertilize not found"
        end

        def create(create_input_dto)
          fertilize = ::Fertilize.new(
            name: create_input_dto.name,
            n: create_input_dto.n,
            p: create_input_dto.p,
            k: create_input_dto.k,
            description: create_input_dto.description,
            package_size: create_input_dto.package_size,
            region: create_input_dto.region,
            is_reference: true,
            user_id: nil
          )
          raise Domain::Shared::Exceptions::RecordInvalid, fertilize.errors.full_messages.join(", ") unless fertilize.save

          Adapters::Fertilize::Mappers::FertilizeMapper.fertilize_entity_from_record(fertilize)
        end
      end
    end
  end
end
