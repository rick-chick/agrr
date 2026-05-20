# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr fields 配列の 1 行。
      class AdjustWithDbWeatherFieldConfigRow
        attr_reader :field_id, :name, :area, :daily_fixed_cost

        def initialize(field_id:, name:, area:, daily_fixed_cost:)
          @field_id = field_id.to_s
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherFieldConfigRow]
        def self.from_hash(h)
          sym = Domain::Shared.symbolize_keys(h.to_hash)
          new(
            field_id: sym.fetch(:field_id),
            name: sym.fetch(:name),
            area: sym.fetch(:area),
            daily_fixed_cost: sym[:daily_fixed_cost] || 0.0
          )
        end
      end
    end
  end
end
