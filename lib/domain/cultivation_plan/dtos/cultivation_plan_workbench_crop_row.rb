# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanWorkbenchCropRow
        attr_reader :id, :name, :area_per_unit, :revenue_per_area

        def initialize(id:, name:, area_per_unit:, revenue_per_area:)
          @id = id
          @name = name
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          freeze
        end
      end
    end
  end
end
