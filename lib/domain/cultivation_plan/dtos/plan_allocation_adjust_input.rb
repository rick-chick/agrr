# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustInput
        attr_reader :plan_id, :moves, :auth

        # @param plan_id [Integer]
        # @param moves [Array<Hash>]
        # @param auth [Domain::CultivationPlan::Dtos::CultivationPlanRestAuth, nil] REST adjust 時のみ（成長段階チェック）
        def initialize(plan_id:, moves:, auth: nil)
          @plan_id = plan_id
          @moves = moves
          @auth = auth
        end

        def rest_adjust?
          !auth.nil?
        end
      end
    end
  end
end
