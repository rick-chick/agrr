# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustReadPlanFieldRowSnapshot
        attr_reader :id, :name, :area, :daily_fixed_cost

        def initialize(id:, name:, area:, daily_fixed_cost:)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          freeze
        end
      end
    end
  end
end
