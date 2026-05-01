# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存フローの Domain 抽象。
      # 実体は AR を扱う Adapters::CultivationPlan::Sessions::PlanSaveSession。
      class PublicPlanSaveGateway
        def initialize(logger:)
          @logger = logger
        end

        # @param user  [User]
        # @param session_data [Hash]
        # @return [Adapters::CultivationPlan::Sessions::PlanSaveSession::Result]
        def save_from_session(user:, session_data:)
          ::Adapters::CultivationPlan::Sessions::PlanSaveSession.new(
            user: user,
            session_data: session_data,
            logger: @logger
          ).call
        end
      end
    end
  end
end
