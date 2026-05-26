# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanSaveEnsureUserCropsInput
        attr_reader :user_id, :plan_id

        # @param user_id [Integer, #to_i]
        # @param plan_id [Integer, #to_i]
        def initialize(user_id:, plan_id:)
          @user_id = user_id.to_i
          @plan_id = plan_id.to_i
          freeze
        end
      end
    end
  end
end
