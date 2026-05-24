# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST: 最適化関連の Action Cable 通知。
      # `broadcast_field_*` は表示用ペイロードを呼び出し元で組み立て済み。
      # `broadcast_optimization_complete` はアダプター内で I18n および plan サマリ値を組み立てる。
      class CultivationPlanOptimizationEventsGateway
        def broadcast_field_added(plan_id:, plan_type:, field_snapshot:, total_area:)
          raise NotImplementedError
        end

        def broadcast_field_removed(plan_id:, plan_type:, field_id:, total_area:)
          raise NotImplementedError
        end

        # adjust / 最適化完了時の Action Cable 通知（channel 選択とペイロードはアダプターで実施）
        def broadcast_optimization_complete(plan_id:, status:)
          raise NotImplementedError
        end
      end
    end
  end
end
