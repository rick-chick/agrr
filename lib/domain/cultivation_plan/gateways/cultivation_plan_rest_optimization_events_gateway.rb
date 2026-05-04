# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST: 圃場変更時の最適化チャンネル通知（表示用ペイロードは呼び出し元で組み立て済み）。
      class CultivationPlanRestOptimizationEventsGateway
        def broadcast_field_added(plan:, field_payload:, total_area:)
          raise NotImplementedError
        end

        def broadcast_field_removed(plan:, field_id:, total_area:)
          raise NotImplementedError
        end
      end
    end
  end
end
