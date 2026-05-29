# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class OptimizationPlanReadPlanCoreSnapshot
        attr_reader :plan_id,
                    :plan_type_private,
                    :calculated_planning_start_date,
                    :calculated_planning_end_date,
                    :prediction_target_end_date,
                    :predicted_weather_data,
                    :total_area,
                    :weather_location_present

        def initialize(
          plan_id:,
          plan_type_private:,
          calculated_planning_start_date:,
          calculated_planning_end_date:,
          prediction_target_end_date:,
          predicted_weather_data:,
          total_area:,
          weather_location_present:
        )
          @plan_id = plan_id
          @plan_type_private = plan_type_private
          @calculated_planning_start_date = calculated_planning_start_date
          @calculated_planning_end_date = calculated_planning_end_date
          @prediction_target_end_date = prediction_target_end_date
          @predicted_weather_data = predicted_weather_data
          @total_area = total_area
          @weather_location_present = weather_location_present
          freeze
        end
      end
    end
  end
end
