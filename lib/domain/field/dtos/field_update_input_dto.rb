# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldUpdateInputDto
        attr_reader :id, :name, :area, :daily_fixed_cost, :region

        def initialize(id:, name: nil, area: nil, daily_fixed_cost: nil, region: nil)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
        end

        def self.from_hash(hash, field_id)
          pp = hash[:field] || hash
          new(
            id: field_id,
            name: pp[:name],
            area: pp[:area],
            daily_fixed_cost: pp[:daily_fixed_cost],
            region: pp[:region]
          )
        end
      end
    end
  end
end
