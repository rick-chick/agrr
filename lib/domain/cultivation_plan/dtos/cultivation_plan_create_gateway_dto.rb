# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanCreateGatewayDto
        attr_reader :farm, :crops, :user, :plan_name, :total_area

        def initialize(farm:, crops:, user:, plan_name:, total_area:)
          @farm = farm
          @crops = crops
          @user = user
          @plan_name = plan_name
          @total_area = total_area
        end
      end
    end
  end
end