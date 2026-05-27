# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST adjust 前: 計画作物の生育段階件数読取（永続のみ）。
      class CultivationPlanAdjustPlanGrowthReadGateway
        def initialize(logger:)
          @logger = logger
        end

        # @param plan_id [Integer, String]
        # @param user_id [Integer]
        # @return [Array<Domain::CultivationPlan::Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot>]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def list_by_plan_id_and_user_id(plan_id:, user_id:)
          raise NotImplementedError
        end

        # @param plan_id [Integer, String]
        # @return [Array<Domain::CultivationPlan::Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot>]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def list_by_plan_id(plan_id:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
