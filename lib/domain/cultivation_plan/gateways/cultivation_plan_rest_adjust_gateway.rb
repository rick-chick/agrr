# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST POST adjust: 生育段階検証 + adjust_with_db_weather（単一読み込みで実装する契約）。
      class CultivationPlanRestAdjustGateway
        def initialize(logger:)
          @logger = logger
        end

        # @param moves [Array<Hash>]
        # @return [Hash] Flow 互換: { kind: :adjust_result | :crop_missing_growth_stages | :not_found | :unexpected, ... }
        def execute(auth:, plan_id:, moves:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
