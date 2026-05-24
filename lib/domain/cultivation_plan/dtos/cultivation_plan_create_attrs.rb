# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CultivationPlanGateway#create 用の永続化属性。
      class CultivationPlanCreateAttrs
        attr_reader :farm_id, :user_id, :total_area, :plan_type, :session_id,
                    :plan_year, :plan_name, :planning_start_date, :planning_end_date, :status

        def initialize(
          farm_id:,
          total_area:,
          plan_type:,
          user_id: nil,
          session_id: nil,
          plan_year: nil,
          plan_name: nil,
          planning_start_date: nil,
          planning_end_date: nil,
          status: nil
        )
          @farm_id = farm_id
          @user_id = user_id
          @total_area = total_area
          @plan_type = plan_type
          @session_id = session_id
          @plan_year = plan_year
          @plan_name = plan_name
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @status = status
        end
      end
    end
  end
end
