# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存フローの Domain 抽象。
      # 永続化は CompositionRoot が渡す runner（Adapter セッションの .call）に委譲する。
      class PublicPlanSaveGateway
        def initialize(logger:, save_from_session_runner:)
          @logger = logger
          @save_from_session_runner = save_from_session_runner
        end

        # @param user  [User]
        # @param session_data [Hash]
        # @return [Object] 保存結果（success? 等を持つこと）
        def save_from_session(user:, session_data:)
          @save_from_session_runner.call(user: user, session_data: session_data, logger: @logger)
        end
      end
    end
  end
end
