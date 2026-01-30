# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldCreateInputDto
        attr_reader :name, :area, :daily_fixed_cost, :region

        def initialize(name:, area: nil, daily_fixed_cost: nil, region: nil)
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
        end

        def self.from_hash(hash)
          pp = hash[:field] || hash
          new(
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
