# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プランをユーザーアカウントへ保存するユースケースの失敗区分（Presenter が HTTP/HTML を決める）。
      class PublicPlanSaveFailureDto
        KIND_SAVE_FAILED = :save_failed
        KIND_UNEXPECTED = :unexpected
        KIND_PLAN_NOT_FOUND = :plan_not_found
        KIND_MISSING_PLAN_ID = :missing_plan_id

        attr_reader :kind, :message

        # @param kind [Symbol] one of KIND_* constants
        # @param message [String, nil] user-visible or logged detail
        def initialize(kind:, message: nil)
          @kind = kind
          @message = message
        end
      end
    end
  end
end
