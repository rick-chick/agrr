# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustReadPlanHeaderSnapshot
        attr_reader :id,
                    :planning_start_date,
                    :planning_end_date,
                    :prediction_target_end_date,
                    :calculated_planning_end_date,
                    :predicted_weather_data,
                    :weather_prediction_targets

        def initialize(
          id:,
          planning_start_date:,
          planning_end_date:,
          prediction_target_end_date:,
          calculated_planning_end_date:,
          predicted_weather_data:,
          weather_prediction_targets:
        )
          @id = id
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @prediction_target_end_date = prediction_target_end_date
          @calculated_planning_end_date = calculated_planning_end_date
          @predicted_weather_data = predicted_weather_data
          @weather_prediction_targets = weather_prediction_targets
          freeze
        end
      end
    end
  end
end
