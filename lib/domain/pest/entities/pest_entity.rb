# frozen_string_literal: true

module Domain
  module Pest
    module Entities
      class PestEntity
        attr_reader :id, :name, :name_scientific, :family, :order, :description, :occurrence_season, :is_reference, :created_at, :updated_at
        
        def initialize(attributes)
          @id = attributes[:id]
          @name = attributes[:name]
          @name_scientific = attributes[:name_scientific]
          @family = attributes[:family]
          @order = attributes[:order]
          @description = attributes[:description]
          @occurrence_season = attributes[:occurrence_season]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]
          
          validate!
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




