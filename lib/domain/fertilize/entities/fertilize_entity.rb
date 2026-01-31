# frozen_string_literal: true

module Domain
  module Fertilize
    module Entities
      class FertilizeEntity
        attr_reader :id, :user_id, :name, :n, :p, :k, :description, :package_size, :region, :is_reference, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @n = attributes[:n]
          @p = attributes[:p]
          @k = attributes[:k]
          @description = attributes[:description]
          @package_size = attributes[:package_size]
          @region = attributes[:region]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def to_model
          ::Fertilize.find(id)
        end

        def self.from_model(record)
          new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            n: record.n,
            p: record.p,
            k: record.k,
            description: record.description,
            package_size: record.package_size,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
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

