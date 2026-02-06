# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanCreateGatewayDto
        attr_reader :farm, :total_area, :crops, :user, :session_id, :planning_start_date, :planning_end_date

        def initialize(farm:, total_area:, crops:, user:, session_id:, planning_start_date:, planning_end_date:)
          @farm = farm
          @total_area = total_area
          @crops = crops
          @user = user
          @session_id = session_id
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
        end
      end
    end
  end
end
