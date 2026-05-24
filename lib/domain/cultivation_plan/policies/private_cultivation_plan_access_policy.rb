# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Policies
      # 認証ユーザーが私有計画の所有者か（Gateway / AR 非依存）。
      module PrivateCultivationPlanAccessPolicy
        module_function

        # @param plan [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        # @param user_id [Integer]
        def access_denied?(plan:, user_id:)
          plan.user_id != user_id || !plan.plan_type_private?
        end
      end
    end
  end
end
