# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST: 圃場追加・削除（永続化 + イベント通知のオーケストレーション契約）。
      # 実装はアダプタ。Interactor への戻りは { kind: Symbol, ... }（既存Presenter契約）。
      class CultivationPlanRestFieldMutationGateway
        def initialize(events_gateway:, logger:)
          @events_gateway = events_gateway
          @logger = logger
        end

        def add_field(auth:, plan_id:, field_name:, field_area:, daily_fixed_cost:)
          raise NotImplementedError
        end

        def remove_field(auth:, plan_id:, field_id_param:)
          raise NotImplementedError
        end

        protected

        attr_reader :events_gateway, :logger
      end
    end
  end
end
