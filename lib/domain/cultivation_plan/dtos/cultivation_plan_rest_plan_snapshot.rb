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

      class CultivationPlanRestPlanCropRowSnapshot
        attr_reader :id, :display_name, :area_per_unit, :revenue_per_area

        def initialize(id:, display_name:, area_per_unit:, revenue_per_area:)
          @id = id
          @display_name = display_name
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          freeze
        end
      end

      class CultivationPlanRestPlanCultivationRowSnapshot
        attr_reader :id,
                    :cultivation_plan_field_id,
                    :field_display_name,
                    :cultivation_plan_crop_id,
                    :crop_display_name,
                    :area,
                    :start_date,
                    :completion_date,
                    :cultivation_days,
                    :estimated_cost,
                    :optimization_result,
                    :status

        def initialize(
          id:,
          cultivation_plan_field_id:,
          field_display_name:,
          cultivation_plan_crop_id:,
          crop_display_name:,
          area:,
          start_date:,
          completion_date:,
          cultivation_days:,
          estimated_cost:,
          optimization_result:,
          status:
        )
          @id = id
          @cultivation_plan_field_id = cultivation_plan_field_id
          @field_display_name = field_display_name
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @crop_display_name = crop_display_name
          @area = area
          @start_date = start_date
          @completion_date = completion_date
          @cultivation_days = cultivation_days
          @estimated_cost = estimated_cost
          @optimization_result = optimization_result
          @status = status
          freeze
        end
      end

      class CultivationPlanRestPlanSnapshot
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
                    :farm_region,
                    :field_rows,
                    :crop_rows,
                    :cultivation_rows,
                    :palette_crop_ids

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
          farm_region:,
          field_rows:,
          crop_rows:,
          cultivation_rows:,
          palette_crop_ids:
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
          @field_rows = field_rows
          @crop_rows = crop_rows
          @cultivation_rows = cultivation_rows
          @palette_crop_ids = palette_crop_ids
          freeze
        end
      end
    end
  end
end
