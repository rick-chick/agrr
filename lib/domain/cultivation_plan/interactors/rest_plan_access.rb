# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # REST 変更系: Entity scalar から読取・変更可否を判定（Gateway / AR 非依存）。
      module RestPlanAccess
        module_function

        # @param plan [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        # @param auth [Domain::CultivationPlan::Dtos::CultivationPlanRestAuth]
        def access_denied?(plan:, auth:)
          if auth.private?
            Policies::PrivateCultivationPlanAccessPolicy.access_denied?(plan: plan, user_id: auth.user_id)
          else
            !Policies::PlanReadAuthorization.public_plan?(plan_type: plan.plan_type)
          end
        end
      end
    end
  end
end
