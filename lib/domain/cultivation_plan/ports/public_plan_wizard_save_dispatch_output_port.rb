# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # 公開プラン結果ページの「保存」— 計画欠落・ペイロード欠落・ログイン要請・保存結果を表す。
      class PublicPlanWizardSaveDispatchOutputPort < PublicPlanSaveFromSessionOutputPort
        def on_plan_not_found
          raise NotImplementedError
        end

        # @param plan_id [Integer]
        def on_save_payload_unavailable(plan_id:)
          raise NotImplementedError
        end

        # @param session_data [Hash]
        def on_requires_login(session_data:)
          raise NotImplementedError
        end
      end
    end
  end
end
