# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 作業予定 mutation: private 計画の所有者チェック（Gateway / AR 非依存）。
      module TaskSchedulePrivatePlanAccess
        module_function

        # @return [Boolean] true = 続行可, false = plan 不在または access denied
        def access_allowed?(plan_gateway:, plan_id:, user_id:)
          plan = plan_gateway.find_by_id(plan_id)
          !Policies::PrivateCultivationPlanAccessPolicy.access_denied?(plan: plan, user_id: user_id)
        rescue Domain::Shared::Exceptions::RecordNotFound
          false
        end
      end
    end
  end
end
