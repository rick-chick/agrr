# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data: 計画ワークベンチ用 JSON ボディ組み立て（永続読取のみ Gateway 側）。
      class CultivationPlanRestWorkbenchPayloadGateway
        def initialize(logger:)
          @logger = logger
        end

        # available_crop_rows: [{ id:, name:, variety:, area_per_unit: }, ...]（認可・一覧解決はコントローラで実施済み）
        def build(auth:, plan_id:, available_crop_rows:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
