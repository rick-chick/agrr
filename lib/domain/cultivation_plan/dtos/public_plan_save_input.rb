# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # POST /api/v1/public_plans/save_plan の入力（Controller edge で構築）。
      class PublicPlanSaveInput
        attr_reader :plan_id, :user_id, :session_data

        # @param plan_id [Integer, String, nil]
        # @param user_id [Integer]
        # @param session_data [PublicPlanSaveSessionData, nil] セッション経路用。API は nil。
        def initialize(plan_id:, user_id:, session_data: nil)
          @plan_id = plan_id
          @user_id = user_id.to_i
          @session_data = session_data
          freeze
        end

        def plan_id_present?
          !@plan_id.nil? && !@plan_id.to_s.strip.empty?
        end
      end
    end
  end
end
