# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Policies
      # 圃場栽培と親 CultivationPlan の閲覧・更新可否（旧 Gateway 内ロジックと同一）。
      class PlanFieldCultivationAccess
        def self.view_allowed?(user, context)
          return true if context.plan_type_public?

          user.admin? || (context.plan_type_private? && context.plan_user_id == user.id)
        end

        def self.assert_view_allowed!(user, context)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless view_allowed?(user, context)
        end

        def self.assert_edit_allowed!(user, context)
          assert_view_allowed!(user, context)
        end
      end
    end
  end
end
