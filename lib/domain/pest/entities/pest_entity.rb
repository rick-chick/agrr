# frozen_string_literal: true

module Domain
  module Pest
    module Entities
      class PestEntity
        attr_reader :id, :user_id, :name, :name_scientific, :family, :order, :description, :occurrence_season, :region, :is_reference, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @name_scientific = attributes[:name_scientific]
          @family = attributes[:family]
          @order = attributes[:order]
          @description = attributes[:description]
          @occurrence_season = attributes[:occurrence_season]
          @region = attributes[:region]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        # 配列用メソッド: pests.recent.each のために recent 配列を返す
        def self.recent(pests)
          pests.sort_by { |p| -p.created_at.to_i }
        end

        def to_hash
          {
            id: id,
            name: name,
            name_scientific: name_scientific,
            family: family,
            order: order,
            description: description,
            occurrence_season: occurrence_season,
            is_reference: is_reference,
            created_at: created_at,
            updated_at: updated_at
          }
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if Domain::Shared.blank?(name)
          validate_region!
        end

        def validate_region!
          return if region.nil?

          allowed_regions = %w[jp us in]
          unless allowed_regions.include?(region)
            raise ArgumentError, "Region must be one of: #{allowed_regions.join(', ')}"
          end
        end
      end
    end
  end
end
