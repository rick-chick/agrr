# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanRestPlanHeaderSnapshot
        attr_reader :id,
                    :user_id,
                    :plan_year,
                    :plan_name,
                    :display_name,
                    :plan_type,
                    :status,
                    :total_area,
                    :planning_start_date,
                    :planning_end_date,
                    :calculated_planning_start_date,
                    :prediction_target_end_date,
                    :total_profit,
                    :total_revenue,
                    :total_cost,
                    :farm_display_name,
                    :farm_region

        def initialize(
          id:,
          user_id:,
          plan_year:,
          plan_name:,
          display_name:,
          plan_type:,
          status:,
          total_area:,
          planning_start_date:,
          planning_end_date:,
          calculated_planning_start_date:,
          prediction_target_end_date:,
          total_profit:,
          total_revenue:,
          total_cost:,
          farm_display_name:,
          farm_region:
        )
          @id = id
          @user_id = user_id
          @plan_year = plan_year
          @plan_name = plan_name
          @display_name = display_name
          @plan_type = plan_type
          @status = status
          @total_area = total_area
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @calculated_planning_start_date = calculated_planning_start_date
          @prediction_target_end_date = prediction_target_end_date
          @total_profit = total_profit
          @total_revenue = total_revenue
          @total_cost = total_cost
          @farm_display_name = farm_display_name
          @farm_region = farm_region
          freeze
        end
      end
    end
  end
end
