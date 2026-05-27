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

        # @param user [#id]
        # @param plan [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def assert_private_owned!(user, plan)
          raise Domain::Shared::Policies::PolicyPermissionDenied if access_denied?(plan: plan, user_id: user.id)
        end
      end
    end
  end
end
