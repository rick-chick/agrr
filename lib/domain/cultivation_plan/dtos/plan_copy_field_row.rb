# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanCopyFieldRow
        attr_reader :id, :name, :area, :daily_fixed_cost, :description

        def initialize(id:, name:, area:, daily_fixed_cost:, description: nil)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @description = description
        end
      end
    end
  end
end
