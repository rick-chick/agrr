# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Entities
      # 永続化された栽培計画（Adapter→Interactor 向けスナップショット）
      class CultivationPlanEntity
        attr_reader :id, :farm_id, :user_id, :total_area, :plan_type, :plan_year, :plan_name,
                    :planning_start_date, :planning_end_date, :status, :session_id, :display_name,
                    :cultivation_plan_crops_count, :cultivation_plan_fields_count, :updated_at, :created_at

        def initialize(
          id:,
          farm_id:,
          user_id:,
          total_area:,
          plan_type:,
          plan_year: nil,
          plan_name: nil,
          planning_start_date: nil,
          planning_end_date: nil,
          status: nil,
          session_id: nil,
          display_name: nil,
          cultivation_plan_crops_count: 0,
          cultivation_plan_fields_count: 0,
          created_at: nil,
          updated_at: nil
        )
          @id = id
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
          @display_name = display_name
          @cultivation_plan_crops_count = cultivation_plan_crops_count
          @cultivation_plan_fields_count = cultivation_plan_fields_count
          @created_at = created_at
          @updated_at = updated_at
        end

        def plan_type_private?
          plan_type == "private"
        end
      end
    end
  end
end
