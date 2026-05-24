# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanCopyCropRow
        attr_reader :id, :crop_id, :name, :variety, :area_per_unit, :revenue_per_area

        def initialize(id:, crop_id:, name:, variety: nil, area_per_unit: nil, revenue_per_area: nil)
          @id = id
          @crop_id = crop_id
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
        end
      end
    end
  end
end
