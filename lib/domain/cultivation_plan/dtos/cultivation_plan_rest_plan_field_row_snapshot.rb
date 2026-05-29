# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanRestPlanFieldRowSnapshot
        attr_reader :id, :name, :area, :daily_fixed_cost, :display_name

        def initialize(id:, name:, area:, daily_fixed_cost:, display_name:)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @display_name = display_name
          freeze
        end
      end
    end
  end
end
