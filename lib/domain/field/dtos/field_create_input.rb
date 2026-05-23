# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldCreateInput
        attr_reader :name, :area, :daily_fixed_cost, :region, :farm_id

        def initialize(name:, farm_id:, area: nil, daily_fixed_cost: nil, region: nil)
          @name = name
          @farm_id = farm_id
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
        end

        def self.from_hash(hash, farm_id: nil)
          pp = hash[:field] || hash
          resolved_farm_id = farm_id || hash[:farm_id]
          new(
            name: pp[:name],
            farm_id: resolved_farm_id,
            area: pp[:area],
            daily_fixed_cost: pp[:daily_fixed_cost],
            region: pp[:region]
          )
        end
      end
    end
  end
end
