# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CultivationPlanOptimizeInteractor 用: AR を渡さず計画の読み取りスナップショットを渡す
      class OptimizationPlanSnapshotDto
        attr_reader :plan_id,
                    :plan_type_private,
                    :calculated_planning_start_date,
                    :calculated_planning_end_date,
                    :prediction_target_end_date,
                    :predicted_weather_data,
                    :total_area,
                    :weather_location_present,
                    :weather_location_input,
                    :farm_weather_input

        def initialize(plan_id:,
                       plan_type_private:,
                       calculated_planning_start_date:,
                       calculated_planning_end_date:,
                       prediction_target_end_date:,
                       predicted_weather_data:,
                       total_area:,
                       weather_location_present:,
                       weather_location_input:,
                       farm_weather_input:)
          @plan_id = plan_id
          @plan_type_private = !!(plan_type_private == true)
          @calculated_planning_start_date = calculated_planning_start_date
          @calculated_planning_end_date = calculated_planning_end_date
          @prediction_target_end_date = prediction_target_end_date
          @predicted_weather_data = predicted_weather_data
          @total_area = total_area
          @weather_location_present = !!(weather_location_present == true)
          @weather_location_input = weather_location_input
          @farm_weather_input = farm_weather_input
          freeze
        end
      end
    end
  end
end
