# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data: 計画ワークベンチ用スナップショット読取（永続のみ）。
      class CultivationPlanWorkbenchPayloadGateway
        def initialize(logger:, available_crop_rows_gateway:)
          @logger = logger
          @available_crop_rows_gateway = available_crop_rows_gateway
        end

        # @return [Hash] { kind: :success, snapshot: CultivationPlanWorkbenchSnapshot } など
        def load_snapshot(auth:, plan_id:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger, :available_crop_rows_gateway
      end
    end
  end
end
