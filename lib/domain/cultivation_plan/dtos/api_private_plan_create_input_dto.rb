# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # POST /api/v1/plans（個人計画新規）の入力。Controller が strong params から組み立てる。
      class ApiPrivatePlanCreateInputDto
        attr_reader :farm_id, :crop_ids, :plan_name, :user

        def initialize(farm_id:, crop_ids:, user:, plan_name: nil)
          @farm_id = farm_id
          @crop_ids = Array(crop_ids).map(&:to_i).reject(&:zero?)
          @plan_name = plan_name
          @user = user
        end
      end
    end
  end
end
