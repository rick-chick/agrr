# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST adjust 前: 計画作物の生育段階件数読取（永続のみ）。
      class CultivationPlanAdjustPlanGrowthReadGateway
        def initialize(logger:)
          @logger = logger
        end

        # @return [Hash] kind: :success（crop_rows, plan_id） / :not_found / :record_invalid / :unexpected
        def load(auth:, plan_id:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
