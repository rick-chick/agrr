# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CropRowsAvailableRow
        attr_reader :id, :name, :variety, :area_per_unit

        def initialize(id:, name:, variety:, area_per_unit:)
          @id = id
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          freeze
        end

        # @return [Hash]
        def to_h
          { id: id, name: name, variety: variety, area_per_unit: area_per_unit }
        end
      end
    end
  end
end
