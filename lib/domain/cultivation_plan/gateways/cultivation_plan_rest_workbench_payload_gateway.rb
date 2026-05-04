# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data: 計画ワークベンチ用 JSON ボディ組み立て（永続読取のみ Gateway 側）。
      class CultivationPlanRestWorkbenchPayloadGateway
        def initialize(logger:, available_crop_rows_gateway:)
          @logger = logger
          @available_crop_rows_gateway = available_crop_rows_gateway
        end

        def build(auth:, plan_id:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger, :available_crop_rows_gateway
      end
    end
  end
end
