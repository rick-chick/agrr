# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustPlanningBoundaries
        attr_reader :planning_start_date, :planning_end_date

        def initialize(planning_start_date:, planning_end_date:)
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          freeze
        end
      end
    end
  end
end
