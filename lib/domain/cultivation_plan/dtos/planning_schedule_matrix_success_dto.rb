# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanningScheduleMatrixSuccessDto
        attr_reader :farm, :selected_fields, :periods, :cultivations_by_field,
          :start_year, :end_year, :year_range, :years_range, :granularity,
          :session_farm_id, :session_field_ids

        def initialize(
          farm:, selected_fields:, periods:, cultivations_by_field:,
          start_year:, end_year:, year_range:, years_range:, granularity:,
          session_farm_id:, session_field_ids:
        )
          @farm = farm
          @selected_fields = selected_fields
          @periods = periods
          @cultivations_by_field = cultivations_by_field
          @start_year = start_year
          @end_year = end_year
          @year_range = year_range
          @years_range = years_range
          @granularity = granularity
          @session_farm_id = session_farm_id
          @session_field_ids = session_field_ids
        end
      end
    end
  end
end
