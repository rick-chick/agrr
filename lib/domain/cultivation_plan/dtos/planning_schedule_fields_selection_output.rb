# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanningScheduleFieldsSelectionOutput
        attr_reader :farms, :selected_farm_id, :selected_farm, :fields, :selected_field_ids, :year_range

        def initialize(farms:, selected_farm_id:, selected_farm:, fields:, selected_field_ids:, year_range:)
          @farms = farms
          @selected_farm_id = selected_farm_id
          @selected_farm = selected_farm
          @fields = fields
          @selected_field_ids = selected_field_ids
          @year_range = year_range
        end
      end
    end
  end
end
