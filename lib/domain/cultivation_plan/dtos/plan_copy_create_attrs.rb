# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanCopyCreateAttrs
        attr_reader :farm_id, :user_id, :total_area, :plan_type, :plan_year, :plan_name,
                    :planning_start_date, :planning_end_date, :status, :session_id

        def initialize(
          farm_id:,
          user_id:,
          total_area:,
          plan_type:,
          plan_year:,
          plan_name:,
          planning_start_date:,
          planning_end_date:,
          status:,
          session_id: nil
        )
          @farm_id = farm_id
          @user_id = user_id
          @total_area = total_area
          @plan_type = plan_type
          @plan_year = plan_year
          @plan_name = plan_name
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @status = status
          @session_id = session_id
        end
      end
    end
  end
end
