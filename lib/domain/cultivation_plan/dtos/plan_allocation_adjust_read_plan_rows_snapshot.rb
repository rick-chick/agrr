# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust: narrow read の行を domain mapper で束ねた入力スナップショット。
      class PlanAllocationAdjustReadPlanRowsSnapshot
        attr_reader :id,
                    :planning_start_date,
                    :planning_end_date,
                    :prediction_target_end_date,
                    :calculated_planning_end_date,
                    :predicted_weather_data,
                    :weather_prediction_targets,
                    :plan_fields,
                    :field_cultivations,
                    :plan_crops

        def initialize(
          id:,
          planning_start_date:,
          planning_end_date:,
          prediction_target_end_date:,
          calculated_planning_end_date:,
          predicted_weather_data:,
          weather_prediction_targets:,
          plan_fields:,
          field_cultivations:,
          plan_crops:
        )
          @id = id
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @prediction_target_end_date = prediction_target_end_date
          @calculated_planning_end_date = calculated_planning_end_date
          @predicted_weather_data = predicted_weather_data
          @weather_prediction_targets = weather_prediction_targets
          @plan_fields = plan_fields
          @field_cultivations = field_cultivations
          @plan_crops = plan_crops
          freeze
        end
      end
    end
  end
end
