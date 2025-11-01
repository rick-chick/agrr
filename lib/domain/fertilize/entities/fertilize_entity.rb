# frozen_string_literal: true

module Domain
  module Fertilize
    module Entities
      class FertilizeEntity
        attr_reader :id, :name, :n, :p, :k, :description, :usage, 
                    :application_rate, :is_reference, :created_at, :updated_at
        
        def initialize(attributes)
          @id = attributes[:id]
          @name = attributes[:name]
          @n = attributes[:n]
          @p = attributes[:p]
          @k = attributes[:k]
          @description = attributes[:description]
          @usage = attributes[:usage]
          @application_rate = attributes[:application_rate]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]
          
          validate!
        end
        
        def reference?
          !!is_reference
        end
        
        def has_nutrient?(nutrient)
          case nutrient.to_sym
          when :n
            n.present? && n > 0
          when :p
            p.present? && p > 0
          when :k
            k.present? && k > 0
          else
            false
          end
        end
        
        def npk_summary
          [n, p, k].compact.map { |v| v.to_i }.join('-')
        end
        
        private
        
        def validate!
          raise ArgumentError, "Name is required" if name.blank?
        end
      end
    end
  end
end

