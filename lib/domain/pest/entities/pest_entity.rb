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

        def self.from_model(record)
          new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            name_scientific: record.name_scientific,
            family: record.family,
            order: record.order,
            description: record.description,
            occurrence_season: record.occurrence_season,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
        
        def reference?
          !!is_reference
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
          raise ArgumentError, "Name is required" if name.blank?
        end
      end
    end
  end
end








