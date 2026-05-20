# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # HTML 表示用 DTO。Entity の生属性を抽出し、HTML に安全に渡す。
      class FertilizeDisplay
        attr_reader :id, :name, :n, :p, :k, :description, :package_size, :is_reference, :created_at, :updated_at

        def initialize(fertilize_entity:)
          @id = fertilize_entity.id
          @name = fertilize_entity.name
          @n = fertilize_entity.n
          @p = fertilize_entity.p
          @k = fertilize_entity.k
          @description = fertilize_entity.description
          @package_size = fertilize_entity.package_size
          @is_reference = fertilize_entity.is_reference
          @created_at = fertilize_entity.created_at
          @updated_at = fertilize_entity.updated_at
        end

        def persisted?
          Domain::Shared.present?(@id)
        end

        def npk_summary
          [ n, p, k ].compact.map { |v| v.to_i }.join("-")
        end
      end
    end
  end
end
