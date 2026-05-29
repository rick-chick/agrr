# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanRestPlanCropRowSnapshot
        attr_reader :id, :display_name, :area_per_unit, :revenue_per_area

        def initialize(id:, display_name:, area_per_unit:, revenue_per_area:)
          @id = id
          @display_name = display_name
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          freeze
        end
      end
    end
  end
end
