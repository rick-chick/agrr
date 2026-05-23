# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanWorkbenchFieldRow
        attr_reader :id, :field_id, :name, :area, :daily_fixed_cost

        def initialize(id:, field_id:, name:, area:, daily_fixed_cost:)
          @id = id
          @field_id = field_id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          freeze
        end
      end
    end
  end
end
