# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskSchedulePlanSnapshot
        attr_reader :id, :predicted_weather_data, :calculated_planning_start_date, :field_cultivations

        def initialize(id:, predicted_weather_data:, calculated_planning_start_date:, field_cultivations:)
          @id = id
          @predicted_weather_data = predicted_weather_data
          @calculated_planning_start_date = calculated_planning_start_date
          @field_cultivations = field_cultivations
        end
      end
    end
  end
end
