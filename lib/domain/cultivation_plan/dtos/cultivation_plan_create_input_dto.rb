# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CultivationPlanCreateInputDto
        attr_reader :farm_id, :plan_name, :crop_ids, :user

        def initialize(farm_id:, plan_name:, crop_ids:, user:)
          @farm_id = farm_id
          @plan_name = plan_name
          @crop_ids = crop_ids
          @user = user
        end
      end
    end
  end
end